import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/role_dropdown.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:smartbiztracker_new/screens/admin/email_confirmation_management_screen.dart';
import 'package:smartbiztracker_new/screens/admin/quick_fix_screen.dart';

class NewUsersScreen extends StatefulWidget {
  const NewUsersScreen({super.key});

  @override
  State<NewUsersScreen> createState() => _NewUsersScreenState();
}

class _NewUsersScreenState extends State<NewUsersScreen> {
  // Initial values for dropdown
  String _selectedRole = UserRole.client.value;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    // Load pending users on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.fetchPendingApprovalUsers();
    });
  }

  // Approve user
  Future<void> _approveUser(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.approveUserAndSetRole(userId, _selectedRole);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت الموافقة على المستخدم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Reject user
  Future<void> _rejectUser(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الرفض'),
        content: const Text('هل أنت متأكد من رفض هذا المستخدم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await authProvider.rejectUser(userId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض المستخدم بنجاح'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'غير متوفر';
    return timeago.format(date, locale: 'ar');
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'owner':
        return 'صاحب عمل';
      case 'client':
        return 'عميل';
      case 'worker':
        return 'عامل';
      case 'accountant':
        return 'محاسب';
      default:
        return 'مستخدم';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'owner':
        return Colors.blue;
      case 'client':
        return Colors.green;
      case 'worker':
        return Colors.orange;
      case 'accountant':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'طلبات التسجيل الجديدة',
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.build_circle),
              tooltip: 'أدوات الإصلاح السريع',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuickFixScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.email_outlined),
              tooltip: 'إدارة تأكيد البريد الإلكتروني',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmailConfirmationManagementScreen(),
                  ),
                );
              },
            ),
          ],
          hideStatusBarHeader: true,
        ),
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: AppRoutes.approvalRequests,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final pendingUsers = authProvider.pendingUsers;

          return Stack(
            children: [
              // Content
              if (authProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (pendingUsers.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 80,
                        color: Colors.grey.withAlpha(128),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا يوجد مستخدمين بانتظار الموافقة',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateProfileDialog(),
                        icon: const Icon(Icons.person_add),
                        label: const Text('إنشاء profile لمستخدم موجود'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                RefreshIndicator(
                  onRefresh: () => authProvider.fetchPendingApprovalUsers(),
                  child: AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pendingUsers.length,
                      itemBuilder: (context, index) {
                        final user = pendingUsers[index];

                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // User information
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            Theme.of(context).primaryColor,
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(user.email),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTimeAgo(user.createdAt),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(),

                                    // Role selection
                                    const Text(
                                      'اختر دور المستخدم:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    RoleDropdown(
                                      initialValue: _selectedRole,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedRole = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // الموافقة / الرفض buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _approveUser(user.id),
                                            icon: const Icon(Icons.check_circle_outline),
                                            label: const Text('موافقة'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _rejectUser(user.id),
                                            icon: const Icon(Icons.cancel_outlined),
                                            label: const Text('رفض'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Loading indicator
              if (authProvider.isLoading) const CustomLoader(),
            ],
          );
        },
      ),
    );
  }

  // إظهار نافذة إنشاء profile للمستخدم الموجود
  void _showCreateProfileDialog() {
    final TextEditingController userIdController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    String selectedRole = 'client';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء Profile لمستخدم موجود'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'للمستخدمين الموجودين في Supabase Dashboard بدون profile',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userIdController,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  hintText: '4d798c1b-ce34-4a4a-b876-cb63c3f9197e',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'الدور',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'client', child: Text('عميل')),
                  DropdownMenuItem(value: 'worker', child: Text('عامل')),
                  DropdownMenuItem(value: 'accountant', child: Text('محاسب')),
                  DropdownMenuItem(value: 'admin', child: Text('مدير')),
                ],
                onChanged: (value) {
                  if (value != null) selectedRole = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (userIdController.text.isNotEmpty && emailController.text.isNotEmpty) {
                Navigator.of(context).pop();

                final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
                final success = await supabaseProvider.createProfileForExistingUser(
                  userIdController.text.trim(),
                  emailController.text.trim(),
                  name: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  role: selectedRole,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'تم إنشاء Profile بنجاح'
                          : 'فشل في إنشاء Profile'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );

                  if (success) {
                    // تحديث قائمة المستخدمين
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    authProvider.fetchPendingApprovalUsers();
                  }
                }
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }
}
