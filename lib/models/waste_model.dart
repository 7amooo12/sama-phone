import 'package:cloud_firestore/cloud_firestore.dart';

class WasteModel {
  WasteModel({
    required this.id,
    required this.productId,
    required this.userId,
    required this.workerId,
    required this.workerName,
    required this.itemName,
    required this.description,
    required this.details,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.status,
    required this.date,
    required this.createdAt,
    this.reason,
    this.notes,
    this.metadata,
  });

  // Alias for fromJson to maintain compatibility
  factory WasteModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return WasteModel.fromJson(map, docId);
  }

  factory WasteModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return WasteModel(
      id: docId ?? json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      workerId: json['workerId']?.toString() ?? '',
      workerName: json['workerName']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      quantity: _parseDouble(json['quantity']) ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      date: _parseDateTime(json['date']) ?? DateTime.now(),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      reason: json['reason']?.toString(),
      notes: json['notes']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }
  final String id;
  final String productId;
  final String userId;
  final String workerId;
  final String workerName;
  final String itemName;
  final String description;
  final String details;
  final double quantity;
  final String unit;
  final String type;
  final String status;
  final DateTime date;
  final DateTime createdAt;
  final String? reason;
  final String? notes;
  final Map<String, dynamic>? metadata;

  // Helper method to safely parse double values
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    try {
      return double.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  // Helper method to safely parse DateTime values
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();

    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'userId': userId,
      'workerId': workerId,
      'workerName': workerName,
      'itemName': itemName,
      'description': description,
      'details': details,
      'quantity': quantity,
      'unit': unit,
      'type': type,
      'status': status,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'reason': reason,
      'notes': notes,
      'metadata': metadata,
    };
  }

  // Alias for toJson to maintain compatibility
  Map<String, dynamic> toMap() {
    return toJson();
  }

  WasteModel copyWith({
    String? id,
    String? productId,
    String? userId,
    String? workerId,
    String? workerName,
    String? itemName,
    String? description,
    String? details,
    double? quantity,
    String? unit,
    String? type,
    String? status,
    DateTime? date,
    DateTime? createdAt,
    String? reason,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return WasteModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      userId: userId ?? this.userId,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      details: details ?? this.details,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }
}
