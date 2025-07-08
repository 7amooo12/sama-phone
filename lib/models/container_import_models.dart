/// Container Import Data Models
///
/// This file contains data models for container import functionality,
/// supporting multiple product names, cartons, quantities, and remarks.

import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Model for individual container import item
class ContainerImportItem {
  final String id;
  final String productName;
  final int numberOfCartons;
  final int piecesPerCarton;
  final int totalQuantity;
  final String remarks;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalData;

  ContainerImportItem({
    required this.id,
    required this.productName,
    required this.numberOfCartons,
    required this.piecesPerCarton,
    required this.totalQuantity,
    required this.remarks,
    required this.createdAt,
    this.additionalData,
  });

  /// Create a new container import item
  factory ContainerImportItem.create({
    required String productName,
    required int numberOfCartons,
    required int piecesPerCarton,
    required int totalQuantity,
    required String remarks,
    Map<String, dynamic>? additionalData,
  }) {
    const uuid = Uuid();
    return ContainerImportItem(
      id: uuid.v4(), // Generate proper UUID instead of timestamp
      productName: productName.trim(),
      numberOfCartons: numberOfCartons,
      piecesPerCarton: piecesPerCarton,
      totalQuantity: totalQuantity,
      remarks: remarks.trim(),
      createdAt: DateTime.now(),
      additionalData: additionalData,
    );
  }

  /// Calculate total pieces (cartons × pieces per carton)
  int get calculatedTotalPieces => numberOfCartons * piecesPerCarton;

  /// Check if calculated total matches provided total
  bool get isQuantityConsistent => calculatedTotalPieces == totalQuantity;

  /// Get quantity discrepancy if any
  int get quantityDiscrepancy => totalQuantity - calculatedTotalPieces;

  /// Check if item has valid data
  bool get isValid {
    return productName.isNotEmpty &&
           numberOfCartons > 0 &&
           piecesPerCarton > 0 &&
           totalQuantity > 0;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'number_of_cartons': numberOfCartons,
      'pieces_per_carton': piecesPerCarton,
      'total_quantity': totalQuantity,
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
      'additional_data': additionalData,
    };
  }

  /// Create from JSON
  factory ContainerImportItem.fromJson(Map<String, dynamic> json) {
    return ContainerImportItem(
      id: json['id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      numberOfCartons: _parseIntSafely(json['number_of_cartons']),
      piecesPerCarton: _parseIntSafely(json['pieces_per_carton']),
      totalQuantity: _parseIntSafely(json['total_quantity']),
      remarks: json['remarks']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      additionalData: json['additional_data'] as Map<String, dynamic>?,
    );
  }

  /// Create a copy with updated values
  ContainerImportItem copyWith({
    String? id,
    String? productName,
    int? numberOfCartons,
    int? piecesPerCarton,
    int? totalQuantity,
    String? remarks,
    DateTime? createdAt,
    Map<String, dynamic>? additionalData,
  }) {
    return ContainerImportItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      numberOfCartons: numberOfCartons ?? this.numberOfCartons,
      piecesPerCarton: piecesPerCarton ?? this.piecesPerCarton,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  /// Safe integer parsing
  static int _parseIntSafely(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    }
    return 0;
  }

  @override
  String toString() {
    return 'ContainerImportItem(id: $id, productName: $productName, cartons: $numberOfCartons, piecesPerCarton: $piecesPerCarton, totalQuantity: $totalQuantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContainerImportItem &&
           other.id == id &&
           other.productName == productName &&
           other.numberOfCartons == numberOfCartons &&
           other.piecesPerCarton == piecesPerCarton &&
           other.totalQuantity == totalQuantity &&
           other.remarks == remarks;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      productName,
      numberOfCartons,
      piecesPerCarton,
      totalQuantity,
      remarks,
    );
  }
}

/// Model for container import batch
class ContainerImportBatch {
  final String id;
  final String filename;
  final String originalFilename;
  final int fileSize;
  final String fileType;
  final List<ContainerImportItem> items;
  final DateTime createdAt;
  final String? createdBy;
  final Map<String, dynamic>? metadata;

  ContainerImportBatch({
    required this.id,
    required this.filename,
    required this.originalFilename,
    required this.fileSize,
    required this.fileType,
    required this.items,
    required this.createdAt,
    this.createdBy,
    this.metadata,
  });

  /// Create a new container import batch
  factory ContainerImportBatch.create({
    required String filename,
    required String originalFilename,
    required int fileSize,
    required String fileType,
    required List<ContainerImportItem> items,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    const uuid = Uuid();
    return ContainerImportBatch(
      id: uuid.v4(), // Generate proper UUID instead of timestamp
      filename: filename,
      originalFilename: originalFilename,
      fileSize: fileSize,
      fileType: fileType,
      items: items,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      metadata: metadata,
    );
  }

  /// Get total number of items
  int get totalItems => items.length;

  /// Get total number of cartons
  int get totalCartons => items.fold(0, (sum, item) => sum + item.numberOfCartons);

  /// Get total quantity
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.totalQuantity);

  /// Get items with quantity discrepancies
  List<ContainerImportItem> get itemsWithDiscrepancies {
    return items.where((item) => !item.isQuantityConsistent).toList();
  }

  /// Get unique product names
  List<String> get uniqueProductNames {
    return items.map((item) => item.productName).toSet().toList();
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'original_filename': originalFilename,
      'file_size': fileSize,
      'file_type': fileType,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory ContainerImportBatch.fromJson(Map<String, dynamic> json) {
    final itemsData = json['items'] as List<dynamic>? ?? [];
    final items = itemsData
        .map((itemData) => ContainerImportItem.fromJson(itemData as Map<String, dynamic>))
        .toList();

    return ContainerImportBatch(
      id: json['id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      originalFilename: json['original_filename']?.toString() ?? '',
      fileSize: json['file_size'] as int? ?? 0,
      fileType: json['file_type']?.toString() ?? '',
      items: items,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      createdBy: json['created_by']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ContainerImportBatch(id: $id, filename: $filename, items: ${items.length})';
  }
}

/// Result of container import processing
class ContainerImportResult {
  final bool success;
  final ContainerImportBatch? batch;
  final List<ContainerImportItem> items;
  final Map<String, int> columnMapping;
  final int totalRows;
  final int processedRows;
  final int skippedRows;
  final List<String> errors;
  final List<String> warnings;
  final double processingTime;

  ContainerImportResult({
    required this.success,
    this.batch,
    required this.items,
    required this.columnMapping,
    required this.totalRows,
    required this.processedRows,
    required this.skippedRows,
    required this.errors,
    required this.warnings,
    required this.processingTime,
  });

  /// Check if there are any issues
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  /// Get success rate
  double get successRate {
    if (totalRows == 0) return 0.0;
    return processedRows / totalRows;
  }

  @override
  String toString() {
    return 'ContainerImportResult(success: $success, items: ${items.length}, errors: ${errors.length}, warnings: ${warnings.length})';
  }
}
