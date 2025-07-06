import 'package:smartbiztracker_new/models/advance_model.dart';
import 'package:smartbiztracker_new/utils/uuid_validator.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Diagnostic utility for advance UUID validation issues
/// 
/// This utility helps identify and report UUID-related issues in advance records
/// that could cause PostgreSQL validation errors during database operations.
class AdvanceUuidDiagnostic {
  
  /// Validates an advance model and reports any UUID issues
  /// 
  /// Returns a list of validation issues found, empty if no issues
  static List<String> validateAdvanceModel(AdvanceModel advance) {
    final issues = <String>[];
    
    try {
      // Check advance ID
      if (advance.id.isEmpty) {
        issues.add('معرف السلفة فارغ');
      } else if (!UuidValidator.isValidUuid(advance.id)) {
        issues.add('معرف السلفة غير صحيح: ${advance.id}');
      }
      
      // Check client ID (only if not empty)
      if (advance.clientId.isNotEmpty && !UuidValidator.isValidUuid(advance.clientId)) {
        issues.add('معرف العميل غير صحيح: ${advance.clientId}');
      }
      
      // Check created_by
      if (advance.createdBy.isEmpty) {
        issues.add('معرف منشئ السلفة فارغ');
      } else if (!UuidValidator.isValidUuid(advance.createdBy)) {
        issues.add('معرف منشئ السلفة غير صحيح: ${advance.createdBy}');
      }
      
      // Check approved_by (only if not null/empty)
      if (advance.approvedBy != null && advance.approvedBy!.isNotEmpty && 
          !UuidValidator.isValidUuid(advance.approvedBy!)) {
        issues.add('معرف معتمد السلفة غير صحيح: ${advance.approvedBy}');
      }
      
    } catch (e) {
      issues.add('خطأ في التحقق من السلفة: $e');
    }
    
    return issues;
  }
  
  /// Validates a list of advance models and reports issues
  /// 
  /// Returns a map of advance ID to list of issues
  static Map<String, List<String>> validateAdvanceList(List<AdvanceModel> advances) {
    final results = <String, List<String>>{};
    
    for (final advance in advances) {
      final issues = validateAdvanceModel(advance);
      if (issues.isNotEmpty) {
        results[advance.id] = issues;
      }
    }
    
    return results;
  }
  
  /// Logs diagnostic information for an advance model
  /// 
  /// Useful for debugging UUID validation issues
  static void logAdvanceDiagnostic(AdvanceModel advance) {
    AppLogger.info('🔍 Advance Diagnostic for ID: ${advance.id}');
    AppLogger.info('  - Advance Name: ${advance.advanceName}');
    AppLogger.info('  - Client ID: ${advance.clientId} (Valid: ${UuidValidator.isValidUuid(advance.clientId)})');
    AppLogger.info('  - Created By: ${advance.createdBy} (Valid: ${UuidValidator.isValidUuid(advance.createdBy)})');
    AppLogger.info('  - Approved By: ${advance.approvedBy} (Valid: ${advance.approvedBy != null ? UuidValidator.isValidUuid(advance.approvedBy!) : 'N/A'})');
    AppLogger.info('  - Status: ${advance.status}');
    AppLogger.info('  - Amount: ${advance.amount}');
    
    final issues = validateAdvanceModel(advance);
    if (issues.isNotEmpty) {
      AppLogger.warning('⚠️ UUID Issues Found:');
      for (final issue in issues) {
        AppLogger.warning('  - $issue');
      }
    } else {
      AppLogger.info('✅ No UUID issues found');
    }
  }
  
  /// Checks if an advance can be safely updated in the database
  /// 
  /// Returns true if all UUID fields are valid for database operations
  static bool canSafelyUpdate(AdvanceModel advance) {
    final issues = validateAdvanceModel(advance);
    return issues.isEmpty;
  }
  
  /// Creates a safe database update map for an advance
  /// 
  /// Only includes UUID fields that are valid, preventing PostgreSQL errors
  static Map<String, dynamic> createSafeDatabaseUpdate(AdvanceModel advance) {
    final data = <String, dynamic>{
      'advance_name': advance.advanceName,
      'amount': advance.amount,
      'status': advance.status,
      'description': advance.description,
      'created_at': advance.createdAt.toIso8601String(),
      'approved_at': advance.approvedAt?.toIso8601String(),
      'paid_at': advance.paidAt?.toIso8601String(),
      'rejected_reason': advance.rejectedReason,
      'metadata': advance.metadata,
    };
    
    // Only add UUID fields if they are valid
    if (UuidValidator.isValidUuid(advance.id)) {
      data['id'] = advance.id;
    }
    
    if (advance.clientId.isNotEmpty && UuidValidator.isValidUuid(advance.clientId)) {
      data['client_id'] = advance.clientId;
    }
    
    if (UuidValidator.isValidUuid(advance.createdBy)) {
      data['created_by'] = advance.createdBy;
    }
    
    if (advance.approvedBy != null && advance.approvedBy!.isNotEmpty && 
        UuidValidator.isValidUuid(advance.approvedBy!)) {
      data['approved_by'] = advance.approvedBy;
    }
    
    return data;
  }
  
  /// Generates a diagnostic report for advance UUID issues
  /// 
  /// Returns a formatted string with diagnostic information
  static String generateDiagnosticReport(List<AdvanceModel> advances) {
    final buffer = StringBuffer();
    buffer.writeln('📊 Advance UUID Diagnostic Report');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total Advances: ${advances.length}');
    buffer.writeln('');
    
    final issueMap = validateAdvanceList(advances);
    
    if (issueMap.isEmpty) {
      buffer.writeln('✅ No UUID issues found in any advance records');
    } else {
      buffer.writeln('⚠️ Found UUID issues in ${issueMap.length} advance records:');
      buffer.writeln('');
      
      issueMap.forEach((advanceId, issues) {
        buffer.writeln('Advance ID: $advanceId');
        for (final issue in issues) {
          buffer.writeln('  - $issue');
        }
        buffer.writeln('');
      });
    }
    
    return buffer.toString();
  }
}
