import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.assignedTo,
    required this.dueDate,
    required this.createdAt,
    this.updatedAt,
    required this.priority,
    required this.attachments,
    required this.adminName,
    required this.category,
    required this.quantity,
    required this.completedQuantity,
    required this.productName,
    required this.progress,
    required this.deadline,
    this.productImage,
    this.workerId,
    this.workerName,
    this.adminId,
    this.productId,
    this.orderId,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      assignedTo: json['assigned_to'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      priority: json['priority'] as String,
      attachments: List<String>.from(json['attachments'] as List),
      adminName: json['admin_name'] as String,
      category: json['category'] as String,
      quantity: json['quantity'] as int,
      completedQuantity: json['completed_quantity'] as int,
      productName: json['product_name'] as String,
      progress: (json['progress'] as num).toDouble(),
      deadline: DateTime.parse(json['deadline'] as String),
      productImage: json['product_image'] as String?,
      workerId: json['worker_id'] as String?,
      workerName: json['worker_name'] as String?,
      adminId: json['admin_id'] as String?,
      productId: json['product_id'] as String?,
      orderId: json['order_id'] as String?,
    );
  }

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: data['title'] as String,
      description: data['description'] as String,
      status: data['status'] as String,
      assignedTo: data['assigned_to'] as String,
      dueDate: (data['due_date'] as Timestamp).toDate(),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: data['updated_at'] != null ? (data['updated_at'] as Timestamp).toDate() : null,
      priority: data['priority'] as String,
      attachments: List<String>.from(data['attachments'] as List),
      adminName: data['admin_name'] as String,
      category: data['category'] as String,
      quantity: data['quantity'] as int,
      completedQuantity: data['completed_quantity'] as int,
      productName: data['product_name'] as String,
      progress: (data['progress'] as num).toDouble(),
      deadline: (data['deadline'] as Timestamp).toDate(),
      productImage: data['product_image'] as String?,
      workerId: data['worker_id'] as String?,
      workerName: data['worker_name'] as String?,
    );
  }
  final String id;
  final String title;
  final String description;
  final String status;
  final String assignedTo;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String priority;
  final List<String> attachments;
  final String adminName;
  final String category;
  final int quantity;
  final int completedQuantity;
  final String productName;
  final double progress;
  final DateTime deadline;
  final String? productImage;
  final String? workerId;
  final String? workerName;
  final String? adminId;
  final String? productId;
  final String? orderId;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'assigned_to': assignedTo,
      'due_date': dueDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'priority': priority,
      'attachments': attachments,
      'admin_name': adminName,
      'category': category,
      'quantity': quantity,
      'completed_quantity': completedQuantity,
      'product_name': productName,
      'progress': progress,
      'deadline': deadline.toIso8601String(),
      'product_image': productImage,
      'worker_id': workerId ?? assignedTo, // Use assignedTo as fallback for worker_id
      'worker_name': workerName,
      'admin_id': adminId,
      'product_id': productId,
      'order_id': orderId,
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? assignedTo,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? priority,
    List<String>? attachments,
    String? adminName,
    String? category,
    int? quantity,
    int? completedQuantity,
    String? productName,
    double? progress,
    DateTime? deadline,
    String? productImage,
    String? workerId,
    String? workerName,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
      attachments: attachments ?? this.attachments,
      adminName: adminName ?? this.adminName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      completedQuantity: completedQuantity ?? this.completedQuantity,
      productName: productName ?? this.productName,
      progress: progress ?? this.progress,
      deadline: deadline ?? this.deadline,
      productImage: productImage ?? this.productImage,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
    );
  }
}