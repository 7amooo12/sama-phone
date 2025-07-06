import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Diagnostic widget to help debug pending users visibility issues
class PendingUsersDiagnosticWidget extends StatefulWidget {
  const PendingUsersDiagnosticWidget({super.key});

  @override
  State<PendingUsersDiagnosticWidget> createState() => _PendingUsersDiagnosticWidgetState();
}

class _PendingUsersDiagnosticWidgetState extends State<PendingUsersDiagnosticWidget> {
  Map<String, dynamic> _diagnosticData = {};
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  Future<void> _runDiagnostic() async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      
      AppLogger.info('🔍 Running pending users diagnostic...');
      
      // Force refresh data
      await supabaseProvider.fetchAllUsers();
      
      final allUsers = supabaseProvider.allUsers;
      final pendingUsers = supabaseProvider.users;
      
      // Count users by status
      final statusCount = <String, int>{};
      final roleCount = <String, int>{};
      
      for (final user in allUsers) {
        statusCount[user.status] = (statusCount[user.status] ?? 0) + 1;
        roleCount[user.role.value] = (roleCount[user.role.value] ?? 0) + 1;
      }
      
      // Manual count of pending users
      final manualPendingCount = allUsers.where((user) => user.status == 'pending').length;
      
      setState(() {
        _diagnosticData = {
          'totalUsers': allUsers.length,
          'pendingUsersGetter': pendingUsers.length,
          'manualPendingCount': manualPendingCount,
          'isLoading': supabaseProvider.isLoading,
          'error': supabaseProvider.error,
          'statusCount': statusCount,
          'roleCount': roleCount,
          'pendingUserDetails': pendingUsers.map((user) => {
            'name': user.name,
            'email': user.email,
            'status': user.status,
            'role': user.role.value,
            'createdAt': user.createdAt.toString(),
          }).toList(),
        };
      });
      
      AppLogger.info('✅ Diagnostic completed');
      
    } catch (e) {
      AppLogger.error('❌ Diagnostic failed: $e');
      setState(() {
        _diagnosticData = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              _diagnosticData['pendingUsersGetter'] == 0 
                ? Icons.warning 
                : Icons.check_circle,
              color: _diagnosticData['pendingUsersGetter'] == 0 
                ? Colors.orange 
                : Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('تشخيص طلبات التسجيل'),
            if (_isRunning) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDiagnosticInfo(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isRunning ? null : _runDiagnostic,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث التشخيص'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _exportLogs,
                      icon: const Icon(Icons.download),
                      label: const Text('تصدير السجلات'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticInfo() {
    if (_diagnosticData.isEmpty) {
      return const Text('جاري تشغيل التشخيص...');
    }

    if (_diagnosticData.containsKey('error')) {
      return Text(
        'خطأ في التشخيص: ${_diagnosticData['error']}',
        style: const TextStyle(color: Colors.red),
      );
    }

    final totalUsers = _diagnosticData['totalUsers'] ?? 0;
    final pendingUsers = _diagnosticData['pendingUsersGetter'] ?? 0;
    final manualPending = _diagnosticData['manualPendingCount'] ?? 0;
    final isLoading = _diagnosticData['isLoading'] ?? false;
    final error = _diagnosticData['error'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الحالة العامة:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('إجمالي المستخدمين', totalUsers.toString()),
        _buildInfoRow('المستخدمون المعلقون (Getter)', pendingUsers.toString()),
        _buildInfoRow('المستخدمون المعلقون (يدوي)', manualPending.toString()),
        _buildInfoRow('حالة التحميل', isLoading ? 'جاري التحميل' : 'مكتمل'),
        if (error != null) _buildInfoRow('خطأ', error, isError: true),
        
        const SizedBox(height: 16),
        
        if (_diagnosticData['statusCount'] != null) ...[
          Text(
            'توزيع حالات المستخدمين:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...(_diagnosticData['statusCount'] as Map<String, int>).entries.map(
            (entry) => _buildInfoRow(entry.key, entry.value.toString()),
          ),
        ],
        
        const SizedBox(height: 16),
        
        if (_diagnosticData['pendingUserDetails'] != null) ...[
          Text(
            'تفاصيل المستخدمين المعلقين:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if ((_diagnosticData['pendingUserDetails'] as List).isEmpty)
            const Text('لا توجد طلبات تسجيل معلقة', style: TextStyle(color: Colors.grey))
          else
            ...(_diagnosticData['pendingUserDetails'] as List).map(
              (user) => Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user['name']} (${user['email']})', 
                           style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('الحالة: ${user['status']} | الدور: ${user['role']}'),
                      Text('تاريخ التسجيل: ${user['createdAt']}', 
                           style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
        ],
        
        const SizedBox(height: 16),
        
        _buildRecommendations(),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red : null,
                fontWeight: isError ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final pendingUsers = _diagnosticData['pendingUsersGetter'] ?? 0;
    final totalUsers = _diagnosticData['totalUsers'] ?? 0;
    final isLoading = _diagnosticData['isLoading'] ?? false;

    List<String> recommendations = [];

    if (totalUsers == 0 && !isLoading) {
      recommendations.add('⚠️ لا توجد مستخدمون في قاعدة البيانات - تحقق من الاتصال');
    }

    if (pendingUsers == 0 && totalUsers > 0) {
      recommendations.add('ℹ️ لا توجد طلبات تسجيل معلقة - إما لا توجد تسجيلات جديدة أو تم الموافقة على الجميع');
    }

    if (pendingUsers > 0) {
      recommendations.add('✅ توجد طلبات تسجيل معلقة - يجب أن تظهر في لوحة التحكم');
    }

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التوصيات:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...recommendations.map(
          (rec) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(rec),
          ),
        ),
      ],
    );
  }

  void _exportLogs() {
    // This would export diagnostic data to logs or file
    AppLogger.info('📊 Pending Users Diagnostic Export:');
    AppLogger.info('Data: ${_diagnosticData.toString()}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تصدير البيانات إلى السجلات'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
