import 'package:cloud_firestore/cloud_firestore.dart';

class ProductivityModel {
  ProductivityModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.productId,
    required this.productName,
    required this.producedQuantity,
    required this.defectiveQuantity,
    required this.efficiency,
    required this.date,
    required this.shift,
    required this.workingHours,
    this.metrics,
    this.notes,
  });

  factory ProductivityModel.fromMap(Map<String, dynamic> map) {
    return ProductivityModel(
      id: map['id'] as String,
      workerId: map['workerId'] as String,
      workerName: map['workerName'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      producedQuantity: map['producedQuantity'] as int,
      defectiveQuantity: map['defectiveQuantity'] as int,
      efficiency: (map['efficiency'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      shift: map['shift'] as String,
      workingHours: map['workingHours'] as int,
      metrics: map['metrics'] as Map<String, dynamic>?,
      notes: map['notes'] as String?,
    );
  }

  // Add fromJson method as an alias for fromMap for consistency
  factory ProductivityModel.fromJson(Map<String, dynamic> json,
      [String? docId]) {
    if (docId != null && json['id'] == null) {
      json['id'] = docId;
    }
    return ProductivityModel.fromMap(json);
  }
  final String id;
  final String workerId;
  final String workerName;
  final String productId;
  final String productName;
  final int producedQuantity;
  final int defectiveQuantity;
  final double efficiency;
  final DateTime date;
  final String shift;
  final int workingHours;
  final Map<String, dynamic>? metrics;
  final String? notes;

  // Add getters after constructors
  String get itemName => productName;
  String get clientName => workerName;
  int get quantity => producedQuantity;
  String get details => notes ?? '';
  int get hours => workingHours;
  double get productionRate => metrics?['productionRate'] as double? ?? 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerId': workerId,
      'workerName': workerName,
      'productId': productId,
      'productName': productName,
      'producedQuantity': producedQuantity,
      'defectiveQuantity': defectiveQuantity,
      'efficiency': efficiency,
      'date': Timestamp.fromDate(date),
      'shift': shift,
      'workingHours': workingHours,
      'metrics': metrics,
      'notes': notes,
    };
  }

  // Add toJson method for compatibility
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workerId': workerId,
      'workerName': workerName,
      'productId': productId,
      'productName': productName,
      'producedQuantity': producedQuantity,
      'defectiveQuantity': defectiveQuantity,
      'efficiency': efficiency,
      'date': date.toIso8601String(),
      'shift': shift,
      'workingHours': workingHours,
      'metrics': metrics,
      'notes': notes,
    };
  }

  ProductivityModel copyWith({
    String? id,
    String? workerId,
    String? workerName,
    String? productId,
    String? productName,
    int? producedQuantity,
    int? defectiveQuantity,
    double? efficiency,
    DateTime? date,
    String? shift,
    int? workingHours,
    Map<String, dynamic>? metrics,
    String? notes,
  }) {
    return ProductivityModel(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      producedQuantity: producedQuantity ?? this.producedQuantity,
      defectiveQuantity: defectiveQuantity ?? this.defectiveQuantity,
      efficiency: efficiency ?? this.efficiency,
      date: date ?? this.date,
      shift: shift ?? this.shift,
      workingHours: workingHours ?? this.workingHours,
      metrics: metrics ?? this.metrics,
      notes: notes ?? this.notes,
    );
  }
}

class ShiftType {
  static const String morning = 'MORNING';
  static const String afternoon = 'AFTERNOON';
  static const String night = 'NIGHT';

  // Add uppercase constants for backward compatibility
  @Deprecated('Use lowercase morning instead')
  static const String MORNING = 'MORNING';
  @Deprecated('Use lowercase afternoon instead')
  static const String AFTERNOON = 'AFTERNOON';
  @Deprecated('Use lowercase night instead')
  static const String NIGHT = 'NIGHT';

  static const List<String> values = [morning, afternoon, night];
}
