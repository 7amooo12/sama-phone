import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnModel {
  ReturnModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.reason,
    required this.status,
    required this.returnDate,
    required this.refundAmount,
    this.attachments,
    this.notes,
    required this.isInspected,
    required this.isRefundable,
    this.inspectedBy,
    this.inspectionDate,
    this.resolution,
    this.condition,
    required this.isResaleable,
    this.returnCategory,
    this.qualityIssue,
    this.isProcessed = false,
    this.processedDate,
  });

  factory ReturnModel.fromMap(Map<String, dynamic> map) {
    return ReturnModel(
      id: map['id'] as String,
      clientId: map['clientId'] as String,
      clientName: map['clientName'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      reason: map['reason'] as String,
      status: map['status'] as String,
      returnDate: (map['returnDate'] as Timestamp).toDate(),
      refundAmount: (map['refundAmount'] as num).toDouble(),
      attachments: (map['attachments'] as List<dynamic>?)?.cast<String>(),
      notes: map['notes'] as String?,
      isInspected: map['isInspected'] as bool,
      isRefundable: map['isRefundable'] as bool,
      inspectedBy: map['inspectedBy'] as String?,
      inspectionDate: map['inspectionDate'] != null
          ? (map['inspectionDate'] as Timestamp).toDate()
          : null,
      resolution: map['resolution'] as String?,
      condition: map['condition'] as String?,
      isResaleable: map['isResaleable'] as bool,
      returnCategory: map['returnCategory'] as String?,
      qualityIssue: map['qualityIssue'] as String?,
      isProcessed: map['isProcessed'] as bool? ?? false,
      processedDate: map['processedDate'] != null
          ? (map['processedDate'] as Timestamp).toDate()
          : null,
    );
  }

  // Add fromJson method as an alias for fromMap for consistency
  factory ReturnModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    if (docId != null && json['id'] == null) {
      json['id'] = docId;
    }
    return ReturnModel.fromMap(json);
  }
  final String id;
  final String clientId;
  final String clientName;
  final String productId;
  final String productName;
  final int quantity;
  final String reason;
  final String status;
  final DateTime returnDate;
  final double refundAmount;
  final List<String>? attachments;
  final String? notes;
  final bool isInspected;
  final bool isRefundable;
  final String? inspectedBy;
  final DateTime? inspectionDate;
  final String? resolution;
  final String? condition;
  final bool isResaleable;
  final String? returnCategory;
  final String? qualityIssue;
  final bool isProcessed;
  final DateTime? processedDate;

  // Add getters after constructors
  String get itemName => productName;
  String get details => reason;
  String get returnReason => reason;
  DateTime get date => returnDate;
  String get productCategory => returnCategory ?? '';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'reason': reason,
      'status': status,
      'returnDate': Timestamp.fromDate(returnDate),
      'refundAmount': refundAmount,
      'attachments': attachments,
      'notes': notes,
      'isInspected': isInspected,
      'isRefundable': isRefundable,
      'inspectedBy': inspectedBy,
      'inspectionDate':
          inspectionDate != null ? Timestamp.fromDate(inspectionDate!) : null,
      'resolution': resolution,
      'condition': condition,
      'isResaleable': isResaleable,
      'returnCategory': returnCategory,
      'qualityIssue': qualityIssue,
      'isProcessed': isProcessed,
      'processedDate':
          processedDate != null ? Timestamp.fromDate(processedDate!) : null,
    };
  }

  ReturnModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? productId,
    String? productName,
    int? quantity,
    String? reason,
    String? status,
    DateTime? returnDate,
    double? refundAmount,
    List<String>? attachments,
    String? notes,
    bool? isInspected,
    bool? isRefundable,
    String? inspectedBy,
    DateTime? inspectionDate,
    String? resolution,
    String? condition,
    bool? isResaleable,
    String? returnCategory,
    String? qualityIssue,
    bool? isProcessed,
    DateTime? processedDate,
  }) {
    return ReturnModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      returnDate: returnDate ?? this.returnDate,
      refundAmount: refundAmount ?? this.refundAmount,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      isInspected: isInspected ?? this.isInspected,
      isRefundable: isRefundable ?? this.isRefundable,
      inspectedBy: inspectedBy ?? this.inspectedBy,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      resolution: resolution ?? this.resolution,
      condition: condition ?? this.condition,
      isResaleable: isResaleable ?? this.isResaleable,
      returnCategory: returnCategory ?? this.returnCategory,
      qualityIssue: qualityIssue ?? this.qualityIssue,
      isProcessed: isProcessed ?? this.isProcessed,
      processedDate: processedDate ?? this.processedDate,
    );
  }
}

class ReturnStatus {
  static const String pending = 'PENDING';
  static const String received = 'RECEIVED';
  static const String inspected = 'INSPECTED';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';
  static const String refunded = 'REFUNDED';
  static const String restocked = 'RESTOCKED';

  // Add uppercase constants for backward compatibility
  @Deprecated('Use lowercase pending instead')
  static const String PENDING = 'PENDING';
  @Deprecated('Use lowercase received instead')
  static const String RECEIVED = 'RECEIVED';
  @Deprecated('Use lowercase inspected instead')
  static const String INSPECTED = 'INSPECTED';
  @Deprecated('Use lowercase approved instead')
  static const String APPROVED = 'APPROVED';
  @Deprecated('Use lowercase rejected instead')
  static const String REJECTED = 'REJECTED';
  @Deprecated('Use lowercase refunded instead')
  static const String REFUNDED = 'REFUNDED';
  @Deprecated('Use lowercase restocked instead')
  static const String RESTOCKED = 'RESTOCKED';

  static const List<String> values = [
    pending,
    received,
    inspected,
    approved,
    rejected,
    refunded,
    restocked
  ];
}

class ReturnReason {
  static const String defective = 'DEFECTIVE';
  static const String wrongItem = 'WRONG_ITEM';
  static const String notAsDescribed = 'NOT_AS_DESCRIBED';
  static const String damagedInTransit = 'DAMAGED_IN_TRANSIT';
  static const String customerDissatisfaction = 'CUSTOMER_DISSATISFACTION';
  static const String sizeFitIssue = 'SIZE_FIT_ISSUE';
  static const String changedMind = 'CHANGED_MIND';
  static const String other = 'OTHER';

  // Add uppercase constants for backward compatibility
  @Deprecated('Use lowercase defective instead')
  static const String DEFECTIVE = 'DEFECTIVE';
  @Deprecated('Use lowercase wrongItem instead')
  static const String WRONG_ITEM = 'WRONG_ITEM';
  @Deprecated('Use lowercase notAsDescribed instead')
  static const String NOT_AS_DESCRIBED = 'NOT_AS_DESCRIBED';
  @Deprecated('Use lowercase damagedInTransit instead')
  static const String DAMAGED_IN_TRANSIT = 'DAMAGED_IN_TRANSIT';
  @Deprecated('Use lowercase customerDissatisfaction instead')
  static const String CUSTOMER_DISSATISFACTION = 'CUSTOMER_DISSATISFACTION';
  @Deprecated('Use lowercase sizeFitIssue instead')
  static const String SIZE_FIT_ISSUE = 'SIZE_FIT_ISSUE';
  @Deprecated('Use lowercase changedMind instead')
  static const String CHANGED_MIND = 'CHANGED_MIND';
  @Deprecated('Use lowercase other instead')
  static const String OTHER = 'OTHER';

  static const List<String> values = [
    defective,
    wrongItem,
    notAsDescribed,
    damagedInTransit,
    customerDissatisfaction,
    sizeFitIssue,
    changedMind,
    other
  ];
}

class ReturnCondition {
  static const String newItem = 'NEW';
  static const String likeNew = 'LIKE_NEW';
  static const String used = 'USED';
  static const String damaged = 'DAMAGED';
  static const String unsalvageable = 'UNSALVAGEABLE';

  // Add uppercase constants for backward compatibility
  @Deprecated('Use lowercase newItem instead')
  static const String NEW = 'NEW';
  @Deprecated('Use lowercase likeNew instead')
  static const String LIKE_NEW = 'LIKE_NEW';
  @Deprecated('Use lowercase used instead')
  static const String USED = 'USED';
  @Deprecated('Use lowercase damaged instead')
  static const String DAMAGED = 'DAMAGED';
  @Deprecated('Use lowercase unsalvageable instead')
  static const String UNSALVAGEABLE = 'UNSALVAGEABLE';

  static const List<String> values = [
    newItem,
    likeNew,
    used,
    damaged,
    unsalvageable
  ];
}

class ReturnCategory {
  static const String qualityIssue = 'QUALITY_ISSUE';
  static const String shippingIssue = 'SHIPPING_ISSUE';
  static const String customerPreference = 'CUSTOMER_PREFERENCE';
  static const String orderError = 'ORDER_ERROR';
  static const String other = 'OTHER';

  // Add uppercase constants for backward compatibility
  @Deprecated('Use lowercase qualityIssue instead')
  static const String QUALITY_ISSUE = 'QUALITY_ISSUE';
  @Deprecated('Use lowercase shippingIssue instead')
  static const String SHIPPING_ISSUE = 'SHIPPING_ISSUE';
  @Deprecated('Use lowercase customerPreference instead')
  static const String CUSTOMER_PREFERENCE = 'CUSTOMER_PREFERENCE';
  @Deprecated('Use lowercase orderError instead')
  static const String ORDER_ERROR = 'ORDER_ERROR';
  @Deprecated('Use lowercase other instead')
  static const String OTHER = 'OTHER';

  static const List<String> values = [
    qualityIssue,
    shippingIssue,
    customerPreference,
    orderError,
    other
  ];
}
