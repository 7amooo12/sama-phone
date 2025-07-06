import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/error_report_model.dart';

class ErrorReportsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'error_reports';

  // Get all error reports for admin
  Future<List<ErrorReport>> getAllErrorReports() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ErrorReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch error reports: $e');
    }
  }

  // Get error reports by customer ID
  Future<List<ErrorReport>> getErrorReportsByCustomer(String customerId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ErrorReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch customer error reports: $e');
    }
  }

  // Get error reports by status
  Future<List<ErrorReport>> getErrorReportsByStatus(String status) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('status', status)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ErrorReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch error reports by status: $e');
    }
  }

  // Get error reports by priority
  Future<List<ErrorReport>> getErrorReportsByPriority(String priority) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('priority', priority)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ErrorReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch error reports by priority: $e');
    }
  }

  // Create a new error report
  Future<ErrorReport> createErrorReport(ErrorReport errorReport) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .insert(errorReport.toJson())
          .select()
          .single();

      return ErrorReport.fromJson(response);
    } catch (e) {
      // Provide user-friendly Arabic error messages
      String errorMessage = 'فشل في إرسال تقرير الخطأ';

      if (e.toString().contains('uuid') || e.toString().contains('UUID')) {
        errorMessage = 'خطأ في معرف المستخدم - يرجى إعادة تسجيل الدخول';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'خطأ في الاتصال - تحقق من الإنترنت';
      } else if (e.toString().contains('JWT') || e.toString().contains('auth')) {
        errorMessage = 'انتهت صلاحية الجلسة - يرجى إعادة تسجيل الدخول';
      } else if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
        errorMessage = 'تم إرسال تقرير مماثل من قبل';
      }

      throw Exception(errorMessage);
    }
  }

  // Update error report status
  Future<void> updateErrorReportStatus(String reportId, String newStatus) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'status': newStatus,
            'resolved_at': newStatus == 'resolved' ? DateTime.now().toIso8601String() : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to update error report status: $e');
    }
  }

  // Add admin notes to error report
  Future<void> addAdminNotes(String reportId, String notes) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'admin_notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to add admin notes: $e');
    }
  }

  // Add admin response to error report
  Future<void> addAdminResponse(String reportId, String response) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'admin_response': response,
            'admin_response_date': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to add admin response: $e');
    }
  }

  // Update error report status and add admin response
  Future<void> updateErrorReportWithResponse(String reportId, String status, String response) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'status': status,
            'admin_response': response,
            'admin_response_date': DateTime.now().toIso8601String(),
            'resolved_at': status == 'resolved' ? DateTime.now().toIso8601String() : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to update error report with response: $e');
    }
  }

  // Assign error report to admin
  Future<void> assignErrorReport(String reportId, String adminId) async {
    try {
      await _supabase
          .from(_tableName)
          .update({'assigned_to': adminId})
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to assign error report: $e');
    }
  }

  // Delete error report
  Future<void> deleteErrorReport(String reportId) async {
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to delete error report: $e');
    }
  }

  // Get error report by ID
  Future<ErrorReport?> getErrorReportById(String reportId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('id', reportId)
          .maybeSingle();

      if (response == null) return null;
      return ErrorReport.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch error report: $e');
    }
  }

  // Get error reports count by status
  Future<Map<String, int>> getErrorReportsCountByStatus() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('status');

      final counts = <String, int>{};
      for (final item in response) {
        final status = item['status'] as String;
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to get error reports count: $e');
    }
  }

  // Search error reports
  Future<List<ErrorReport>> searchErrorReports(String query) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .or('title.ilike.%$query%,description.ilike.%$query%,customer_name.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ErrorReport.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search error reports: $e');
    }
  }

  // Get recent error reports (last 7 days)
  Future<List<ErrorReport>> getRecentErrorReports() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .filter('created_at', 'gte', sevenDaysAgo.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ErrorReport.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recent error reports: $e');
    }
  }

  // Get unresolved error reports count
  Future<int> getUnresolvedErrorReportsCount() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('id')
          .neq('status', 'resolved');

      return response.length;
    } catch (e) {
      throw Exception('Failed to get unresolved error reports count: $e');
    }
  }
}
