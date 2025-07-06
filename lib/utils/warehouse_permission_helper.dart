import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/warehouse_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مساعد تشخيص وإصلاح صلاحيات المخازن
class WarehousePermissionHelper {
  static final WarehouseService _warehouseService = WarehouseService();

  /// تشخيص صلاحيات المستخدم الحالي
  static Future<Map<String, dynamic>> diagnoseCurrentUser() async {
    try {
      AppLogger.info('🔍 بدء تشخيص صلاحيات المستخدم...');
      
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'error': 'لا يوجد مستخدم مسجل دخول',
          'user_id': null,
          'user_data': null,
          'has_permission': false,
        };
      }

      // الحصول على بيانات المستخدم
      final userInfo = await _warehouseService.getCurrentUserInfo();
      
      if (userInfo == null) {
        return {
          'success': false,
          'error': 'لا يمكن الحصول على بيانات المستخدم من user_profiles',
          'user_id': currentUser.id,
          'user_data': null,
          'has_permission': false,
        };
      }

      // التحقق من الصلاحيات - إضافة دور المحاسب للوصول للقراءة
      final role = userInfo['role'] as String?;
      final hasPermission = role != null && ['admin', 'owner', 'warehouse_manager', 'accountant'].contains(role);

      return {
        'success': true,
        'error': null,
        'user_id': currentUser.id,
        'user_data': userInfo,
        'current_role': role,
        'has_permission': hasPermission,
        'required_roles': ['admin', 'owner', 'warehouse_manager', 'accountant'],
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في تشخيص المستخدم: $e');
      return {
        'success': false,
        'error': e.toString(),
        'user_id': null,
        'user_data': null,
        'has_permission': false,
      };
    }
  }

  /// 🚨 SECURITY FIX: Disabled dangerous role escalation function
  /// This function was causing privilege escalation by changing user roles
  static Future<bool> fixCurrentUserPermissions({String targetRole = 'admin'}) async {
    try {
      AppLogger.error('🚨 SECURITY ALERT: Role escalation function disabled for security');
      AppLogger.error('🔒 This function was causing warehouse managers to become admins');
      AppLogger.error('💡 Contact system administrator for proper permission management');

      final diagnosis = await diagnoseCurrentUser();
      if (!diagnosis['success']) {
        AppLogger.error('❌ لا يمكن تشخيص المستخدم: ${diagnosis['error']}');
        return false;
      }

      if (diagnosis['has_permission']) {
        AppLogger.info('✅ المستخدم يملك الصلاحيات بالفعل');
        return true;
      }

      // 🔒 SECURITY: Do NOT modify user roles - this causes privilege escalation
      AppLogger.error('❌ تم تعطيل تعديل الأدوار لأسباب أمنية');
      AppLogger.error('🔒 يرجى الاتصال بمدير النظام لإدارة الصلاحيات بشكل آمن');
      return false;
    } catch (e) {
      AppLogger.error('❌ خطأ في تشخيص صلاحيات المستخدم: $e');
      return false;
    }
  }

  /// عرض حوار تشخيص وإصلاح الصلاحيات
  static Future<void> showPermissionDiagnosisDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => const PermissionDiagnosisDialog(),
    );
  }
}

/// حوار تشخيص وإصلاح الصلاحيات
class PermissionDiagnosisDialog extends StatefulWidget {
  const PermissionDiagnosisDialog({super.key});

  @override
  State<PermissionDiagnosisDialog> createState() => _PermissionDiagnosisDialogState();
}

class _PermissionDiagnosisDialogState extends State<PermissionDiagnosisDialog> {
  Map<String, dynamic>? _diagnosis;
  bool _isLoading = false;
  bool _isFixing = false;

  @override
  void initState() {
    super.initState();
    _runDiagnosis();
  }

  Future<void> _runDiagnosis() async {
    setState(() {
      _isLoading = true;
    });

    final diagnosis = await WarehousePermissionHelper.diagnoseCurrentUser();
    
    setState(() {
      _diagnosis = diagnosis;
      _isLoading = false;
    });
  }

  Future<void> _fixPermissions() async {
    setState(() {
      _isFixing = true;
    });

    final success = await WarehousePermissionHelper.fixCurrentUserPermissions();
    
    if (success) {
      // إعادة تشغيل التشخيص للتحقق من النتيجة
      await _runDiagnosis();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إصلاح الصلاحيات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إصلاح الصلاحيات'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isFixing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تشخيص صلاحيات المخازن'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildDiagnosisContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
        if (_diagnosis != null && !_diagnosis!['has_permission'])
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(Icons.security, color: Colors.red),
                const SizedBox(height: 4),
                const Text(
                  '🚨 تم تعطيل تعديل الأدوار لأسباب أمنية',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'يرجى الاتصال بمدير النظام',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ElevatedButton(
          onPressed: _isLoading ? null : _runDiagnosis,
          child: const Text('إعادة التشخيص'),
        ),
      ],
    );
  }

  Widget _buildDiagnosisContent() {
    if (_diagnosis == null) {
      return const Text('لا توجد بيانات تشخيص');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusCard(),
        const SizedBox(height: 16),
        _buildUserInfoCard(),
        if (_diagnosis!['error'] != null) ...[
          const SizedBox(height: 16),
          _buildErrorCard(),
        ],
      ],
    );
  }

  Widget _buildStatusCard() {
    final hasPermission = _diagnosis!['has_permission'] as bool;
    
    return Card(
      color: hasPermission ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              hasPermission ? Icons.check_circle : Icons.error,
              color: hasPermission ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasPermission 
                    ? 'المستخدم يملك صلاحيات إنشاء المخازن'
                    : 'المستخدم لا يملك صلاحيات إنشاء المخازن',
                style: TextStyle(
                  color: hasPermission ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    final userData = _diagnosis!['user_data'] as Map<String, dynamic>?;
    final userId = _diagnosis!['user_id'] as String?;
    final currentRole = _diagnosis!['current_role'] as String?;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات المستخدم:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('معرف المستخدم: ${userId ?? 'غير متوفر'}'),
            if (userData != null) ...[
              Text('الاسم: ${userData['name'] ?? 'غير متوفر'}'),
              Text('البريد الإلكتروني: ${userData['email'] ?? 'غير متوفر'}'),
              Text('الدور الحالي: ${currentRole ?? 'غير محدد'}'),
              Text('الحالة: ${userData['status'] ?? 'غير متوفر'}'),
            ],
            const SizedBox(height: 8),
            const Text(
              'الأدوار المطلوبة لإنشاء المخازن:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('admin, owner, warehouse_manager'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    final error = _diagnosis!['error'] as String;
    
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'خطأ:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(error),
          ],
        ),
      ),
    );
  }
}
