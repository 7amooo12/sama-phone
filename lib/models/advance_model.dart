/// نموذج السلف
/// Advance Payment Model
import '../utils/uuid_validator.dart';

class AdvanceModel {

  const AdvanceModel({
    required this.id,
    required this.advanceName,
    required this.clientId,
    required this.clientName,
    required this.amount,
    required this.status,
    required this.description,
    required this.createdAt,
    this.approvedAt,
    this.paidAt,
    required this.createdBy,
    this.approvedBy,
    this.rejectedReason,
    this.metadata,
  });

  /// Create from database response with enhanced null safety and UUID validation
  factory AdvanceModel.fromDatabase(Map<String, dynamic> data) {
    // Validate required fields to prevent null check operator errors
    if (data['id'] == null || data['advance_name'] == null || data['amount'] == null ||
        data['status'] == null || data['created_at'] == null || data['created_by'] == null) {
      throw ArgumentError('Missing required fields in advance data: $data');
    }

    // Validate UUID fields to prevent PostgreSQL UUID errors
    final id = data['id'] as String;
    final clientId = data['client_id'] as String?;
    final createdBy = data['created_by'] as String;
    final approvedBy = data['approved_by'] as String?;

    // Validate required UUID fields
    if (!UuidValidator.isValidUuid(id)) {
      throw ArgumentError('Invalid advance ID UUID: $id');
    }
    if (!UuidValidator.isValidUuid(createdBy)) {
      throw ArgumentError('Invalid created_by UUID: $createdBy');
    }

    // Validate optional UUID fields (only if not null/empty)
    if (clientId != null && clientId.isNotEmpty && !UuidValidator.isValidUuid(clientId)) {
      throw ArgumentError('Invalid client_id UUID: $clientId');
    }
    if (approvedBy != null && approvedBy.isNotEmpty && !UuidValidator.isValidUuid(approvedBy)) {
      throw ArgumentError('Invalid approved_by UUID: $approvedBy');
    }

    return AdvanceModel(
      id: id,
      advanceName: data['advance_name'] as String,
      clientId: clientId ?? '', // Keep empty string for backward compatibility, but validate before DB operations
      clientName: data['client_name'] as String? ?? 'عميل غير معروف',
      amount: (data['amount'] as num).toDouble(),
      status: data['status'] as String,
      description: data['description'] as String? ?? '',
      createdAt: DateTime.parse(data['created_at'] as String),
      approvedAt: data['approved_at'] != null
          ? DateTime.parse(data['approved_at'] as String)
          : null,
      paidAt: data['paid_at'] != null
          ? DateTime.parse(data['paid_at'] as String)
          : null,
      createdBy: createdBy,
      approvedBy: approvedBy,
      rejectedReason: data['rejected_reason'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }
  final String id;
  final String advanceName;
  final String clientId;
  final String clientName;
  final double amount;
  final String status; // pending, approved, rejected, paid
  final String description;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final String createdBy;
  final String? approvedBy;
  final String? rejectedReason;
  final Map<String, dynamic>? metadata;

  /// Convert to database format with UUID validation
  Map<String, dynamic> toDatabase() {
    final data = <String, dynamic>{
      'advance_name': advanceName,
      'amount': amount,
      'status': status,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'rejected_reason': rejectedReason,
      'metadata': metadata,
    };

    // Add UUID fields only if they are valid UUIDs
    // This prevents PostgreSQL UUID validation errors from empty strings
    UuidValidator.addUuidToJson(data, 'id', id);
    UuidValidator.addUuidToJson(data, 'client_id', clientId);
    UuidValidator.addUuidToJson(data, 'created_by', createdBy);
    UuidValidator.addUuidToJson(data, 'approved_by', approvedBy);

    return data;
  }

  /// Create a copy with updated fields
  AdvanceModel copyWith({
    String? id,
    String? advanceName,
    String? clientId,
    String? clientName,
    double? amount,
    String? status,
    String? description,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? paidAt,
    String? createdBy,
    String? approvedBy,
    String? rejectedReason,
    Map<String, dynamic>? metadata,
  }) {
    return AdvanceModel(
      id: id ?? this.id,
      advanceName: advanceName ?? this.advanceName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      paidAt: paidAt ?? this.paidAt,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectedReason: rejectedReason ?? this.rejectedReason,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get status color
  String get statusColor {
    switch (status) {
      case 'pending':
        return 'orange';
      case 'approved':
        return 'green';
      case 'rejected':
        return 'red';
      case 'paid':
        return 'blue';
      default:
        return 'grey';
    }
  }

  /// Get status text in Arabic
  String get statusText {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'approved':
        return 'معتمدة';
      case 'rejected':
        return 'مرفوضة';
      case 'paid':
        return 'مدفوعة';
      default:
        return 'غير معروف';
    }
  }

  /// Check if advance can be approved
  bool get canBeApproved => status == 'pending';

  /// Check if advance can be paid
  bool get canBePaid => status == 'approved';

  /// Check if advance can be rejected
  bool get canBeRejected => status == 'pending';

  /// Get formatted amount
  String get formattedAmount => '${amount.toStringAsFixed(2)} جنيه';

  /// Get days since creation
  int get daysSinceCreation => DateTime.now().difference(createdAt).inDays;

  @override
  String toString() {
    return 'AdvanceModel(id: $id, advanceName: $advanceName, clientName: $clientName, amount: $amount, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdvanceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// حالات السلف
enum AdvanceStatus {
  pending('pending', 'في الانتظار'),
  approved('approved', 'معتمدة'),
  rejected('rejected', 'مرفوضة'),
  paid('paid', 'مدفوعة');

  const AdvanceStatus(this.value, this.arabicName);

  final String value;
  final String arabicName;

  static AdvanceStatus fromString(String value) {
    return AdvanceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AdvanceStatus.pending,
    );
  }
}

/// إحصائيات السلف
class AdvanceStatistics {

  const AdvanceStatistics({
    required this.totalAdvances,
    required this.pendingAdvances,
    required this.approvedAdvances,
    required this.rejectedAdvances,
    required this.paidAdvances,
    required this.totalAmount,
    required this.pendingAmount,
    required this.approvedAmount,
    required this.paidAmount,
  });

  factory AdvanceStatistics.fromAdvances(List<AdvanceModel> advances) {
    final int totalAdvances = advances.length;
    int pendingAdvances = 0;
    int approvedAdvances = 0;
    int rejectedAdvances = 0;
    int paidAdvances = 0;
    double totalAmount = 0;
    double pendingAmount = 0;
    double approvedAmount = 0;
    double paidAmount = 0;

    for (final advance in advances) {
      totalAmount += advance.amount;

      switch (advance.status) {
        case 'pending':
          pendingAdvances++;
          pendingAmount += advance.amount;
          break;
        case 'approved':
          approvedAdvances++;
          approvedAmount += advance.amount;
          break;
        case 'rejected':
          rejectedAdvances++;
          break;
        case 'paid':
          paidAdvances++;
          paidAmount += advance.amount;
          break;
      }
    }

    return AdvanceStatistics(
      totalAdvances: totalAdvances,
      pendingAdvances: pendingAdvances,
      approvedAdvances: approvedAdvances,
      rejectedAdvances: rejectedAdvances,
      paidAdvances: paidAdvances,
      totalAmount: totalAmount,
      pendingAmount: pendingAmount,
      approvedAmount: approvedAmount,
      paidAmount: paidAmount,
    );
  }
  final int totalAdvances;
  final int pendingAdvances;
  final int approvedAdvances;
  final int rejectedAdvances;
  final int paidAdvances;
  final double totalAmount;
  final double pendingAmount;
  final double approvedAmount;
  final double paidAmount;
}
