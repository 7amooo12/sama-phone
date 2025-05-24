// import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.userId,
    this.route,
    this.data,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return NotificationModel(
      id: docId ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      isRead: map['isRead'] == true,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      userId: map['userId']?.toString() ?? '',
      route: map['route']?.toString(),
      data: map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : null,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json,
      [String? docId]) {
    return NotificationModel(
      id: docId ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRead: json['isRead'] == true,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      userId: json['userId']?.toString() ?? '',
      route: json['route']?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
    );
  }
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String userId;
  final String? route;
  final Map<String, dynamic>? data;

  // Helper method to safely parse DateTime values
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    // if (value is Timestamp) return value.toDate(); // Firebase Timestamp removed

    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(), // Changed from Timestamp to ISO string
      'userId': userId,
      'route': route,
      'data': data,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    String? userId,
    String? route,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      route: route ?? this.route,
      data: data ?? this.data,
    );
  }
}

class NotificationType {
  static const String system = 'SYSTEM';
  static const String order = 'ORDER';
  static const String chat = 'CHAT';
  static const String alert = 'ALERT';
  static const String task = 'TASK';
  static const String update = 'UPDATE';
  static const String reminder = 'REMINDER';

  static const List<String> values = [
    system,
    order,
    chat,
    alert,
    task,
    update,
    reminder
  ];
}

class NotificationPriority {
  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';
  static const String urgent = 'URGENT';

  static const List<String> values = [low, medium, high, urgent];
}

class NotificationCategory {
  static const String orderStatus = 'ORDER_STATUS';
  static const String inventory = 'INVENTORY';
  static const String maintenance = 'MAINTENANCE';
  static const String quality = 'QUALITY';
  static const String production = 'PRODUCTION';
  static const String delivery = 'DELIVERY';
  static const String general = 'GENERAL';

  static const List<String> values = [
    orderStatus,
    inventory,
    maintenance,
    quality,
    production,
    delivery,
    general
  ];
}

class NotificationActionType {
  static const String view = 'VIEW';
  static const String approve = 'APPROVE';
  static const String reject = 'REJECT';
  static const String navigate = 'NAVIGATE';
  static const String custom = 'CUSTOM';

  static const List<String> values = [view, approve, reject, navigate, custom];
}
