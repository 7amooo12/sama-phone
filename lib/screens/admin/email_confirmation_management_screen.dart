import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/supabase_provider.dart';
import '../../services/email_confirmation_service.dart';
import '../../utils/app_logger.dart';
import '../../widgets/common/custom_app_bar.dart';

class EmailConfirmationManagementScreen extends StatefulWidget {
  const EmailConfirmationManagementScreen({super.key});

  @override
  State<EmailConfirmationManagementScreen> createState() => _EmailConfirmationManagementScreenState();
}

class _EmailConfirmationManagementScreenState extends State<EmailConfirmationManagementScreen> {
  List<EmailConfirmationInfo> _stuckUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStuckUsers();
  }

  Future<void> _loadStuckUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final allUsers = await supabaseProvider.getAllUsers();
      
      final List<EmailConfirmationInfo> stuckUsers = [];
      
      for (final user in allUsers) {
        try {
          final info = await EmailConfirmationService.getConfirmationInfo(user.id);
          if (info.isStuck) {
            stuckUsers.add(info);
          }
        } catch (e) {
          AppLogger.error('Error checking user ${user.id}: $e');
        }
      }

      setState(() {
        _stuckUsers = stuckUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fixUserConfirmation(EmailConfirmationInfo info) async {
    try {
      final success = await EmailConfirmationService.fixStuckConfirmation(info.userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إصلاح حالة التأكيد للمستخدم ${info.email}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStuckUsers(); // إعادة تحميل القائمة
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إصلاح حالة التأكيد للمستخدم ${info.email}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendConfirmationEmail(EmailConfirmationInfo info) async {
    try {
      final success = await EmailConfirmationService.resendConfirmationEmail(info.email);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إعادة إرسال بريد التأكيد إلى ${info.email}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إعادة إرسال بريد التأكيد إلى ${info.email}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const CustomAppBar(
        title: 'إدارة تأكيد البريد الإلكتروني',
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('خطأ: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStuckUsers,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _stuckUsers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد مشاكل في تأكيد البريد الإلكتروني',
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'جميع المستخدمين المعتمدين لديهم بريد إلكتروني مؤكد',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadStuckUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _stuckUsers.length,
                        itemBuilder: (context, index) {
                          final info = _stuckUsers[index];
                          return _buildUserCard(info);
                        },
                      ),
                    ),
    );
  }

  Widget _buildUserCard(EmailConfirmationInfo info) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'عالق',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('معرف المستخدم:', info.userId),
            _buildInfoRow('موافق من الأدمن:', info.isApproved ? 'نعم' : 'لا'),
            _buildInfoRow('البريد مؤكد:', info.isEmailConfirmed ? 'نعم' : 'لا'),
            _buildInfoRow('تاريخ الإنشاء:', _formatDate(info.createdAt)),
            if (info.isExpired)
              _buildInfoRow('الحالة:', 'انتهت صلاحية رابط التأكيد', isWarning: true),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _fixUserConfirmation(info),
                    icon: const Icon(Icons.build_circle),
                    label: const Text('إصلاح تلقائي'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _resendConfirmationEmail(info),
                    icon: const Icon(Icons.email),
                    label: const Text('إعادة إرسال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isWarning ? Colors.orange[800] : Colors.black87,
                fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
