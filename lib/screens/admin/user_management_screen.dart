import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/models/models.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/widgets/common/loading_overlay.dart';
import 'package:smartbiztracker_new/models/user_role.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // قائمة المستخدمين
  List<UserModel> _users = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // استدعاء المستخدمين من Firestore
    _loadUsers();
  }

  // استدعاء المستخدمين من Firestore
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
      
      // استدعاء جميع المستخدمين من AuthProvider
      await authProvider.getAllUsers();
      
      setState(() {
        _users = authProvider.allUsers;
      });
    } catch (e) {
      AppLogger.error('Error loading users: $e');
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل المستخدمين';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: CustomAppBar(
            title: 'إدارة المستخدمين',
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            hideStatusBarHeader: true,
          ),
        ),
        drawer: MainDrawer(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          currentRoute: AppRoutes.userManagement,
        ),
        body: _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadUsers,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : _buildContent(theme),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Show dialog to add new user
            _showAddUserDialog();
          },
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      children: [
        // Search bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GlassSearchBar(
                  controller: _searchController,
                  hintText: 'بحث عن مستخدم...',
                  accentColor: theme.colorScheme.primary,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onClear: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث',
                onPressed: _loadUsers,
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.safeOpacity(0.7),
            tabs: const [
              Tab(text: 'الكل'),
              Tab(text: 'المدراء'),
              Tab(text: 'المستخدمون'),
              Tab(text: 'بانتظار الموافقة'),
            ],
          ),
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // All users
              _buildUsersList(theme, null),

              // Admins
              _buildUsersList(theme, UserRole.admin),

              // Clients and other users
              _buildUsersList(theme, UserRole.client,
                  includeWorkers: true, includeOwners: true),

              // Pending approval
              _buildUsersList(theme, null, pendingOnly: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsersList(
    ThemeData theme,
    UserRole? filterRole, {
    bool includeWorkers = false,
    bool includeOwners = false,
    bool pendingOnly = false,
  }) {
    // Filter users based on role, approval status, and search query
    final List<UserModel> filteredUsers = _users.where((user) {
      // Filter by approval status if needed
      if (pendingOnly && user.status != 'active') return false;

      // Filter by role if specified
      if (filterRole != null && user.role != filterRole) {
        // Include workers and owners if needed
        if (includeWorkers && user.role == UserRole.worker) {
          // Include
        } else if (includeOwners && user.role == UserRole.owner) {
          // Include
        } else {
          return false;
        }
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            (user.phone != null && user.phone!.contains(query));
      }

      return true;
    }).toList();

    if (filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          final user = filteredUsers[index];

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: user.status != 'active'
                        ? BorderSide(color: theme.colorScheme.error, width: 1)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor:
                                  _getRoleColor(user.role).safeOpacity(0.2),
                              backgroundImage: user.profileImage != null
                                  ? NetworkImage(user.profileImage!)
                                  : null,
                              child: user.profileImage == null
                                  ? Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: _getRoleColor(user.role),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildRoleBadge(user.role, theme),
                                      if (user.status != 'active')
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.safeOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'غير نشط',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .safeOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.phone ?? 'لا يوجد رقم هاتف',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .safeOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'تاريخ التسجيل: ${_formatDate(user.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .safeOpacity(0.5),
                              ),
                            ),
                            const Spacer(),
                            if (user.status != 'active')
                              TextButton.icon(
                                onPressed: () {
                                  // Handle approve user
                                  _approveUser(user.id);
                                },
                                icon: const Icon(Icons.check_circle),
                                label: const Text('موافقة'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
                              ),
                            TextButton.icon(
                              onPressed: () {
                                // Handle edit user
                                _showEditUserDialog(user);
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('تعديل'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                // Handle delete user
                                _showDeleteUserDialog(user.id);
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('حذف'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty_state.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 16),
          const Text(
            'لا يوجد مستخدمين',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'حاول البحث بمعايير أخرى أو أضف مستخدمين جدد',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role, ThemeData theme) {
    Color color;
    String text;

    switch (role) {
      case UserRole.admin:
        color = Colors.red;
        text = 'مدير';
        break;
      case UserRole.owner:
        color = Colors.blue;
        text = 'صاحب عمل';
        break;
      case UserRole.worker:
        color = Colors.green;
        text = 'عامل';
        break;
      case UserRole.accountant:
        color = Colors.orange;
        text = 'محاسب';
        break;
      case UserRole.client:
        color = Colors.purple;
        text = 'عميل';
        break;
      case UserRole.manager:
        color = Colors.teal;
        text = 'مدير';
        break;
      case UserRole.user:
        color = Colors.grey;
        text = 'مستخدم';
        break;
      case UserRole.pending:
        color = Colors.brown;
        text = 'معلق';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.safeOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.owner:
        return Colors.blue;
      case UserRole.worker:
        return Colors.green;
      case UserRole.accountant:
        return Colors.orange;
      case UserRole.client:
        return Colors.purple;
      case UserRole.manager:
        return Colors.teal;
      case UserRole.user:
        return Colors.grey;
      case UserRole.pending:
        return Colors.brown;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _approveUser(String userId) {
    // Find user by ID and update approval status
    final index = _users.indexWhere((user) => user.id == userId);
    if (index != -1) {
      setState(() {
        _users[index] = _users[index].copyWith(
          status: 'active',
          updatedAt: DateTime.now(),
        );
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت الموافقة على المستخدم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    UserRole selectedRole = UserRole.client;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مستخدم جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
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
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'الدور',
                  border: OutlineInputBorder(),
                ),
                items: UserRole.values.map((role) {
                  String label;
                  switch (role) {
                    case UserRole.admin:
                      label = 'مدير';
                      break;
                    case UserRole.client:
                      label = 'عميل';
                      break;
                    case UserRole.worker:
                      label = 'عامل';
                      break;
                    case UserRole.owner:
                      label = 'صاحب عمل';
                      break;
                    case UserRole.accountant:
                      label = 'محاسب';
                      break;
                    case UserRole.manager:
                      label = 'مدير';
                      break;
                    case UserRole.user:
                      label = 'مستخدم';
                      break;
                    case UserRole.pending:
                      label = 'معلق';
                      break;
                  }
                  return DropdownMenuItem<UserRole>(
                    value: role,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedRole = value;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              // Validate input
              if (nameController.text.trim().isEmpty ||
                  emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء إدخال الاسم والبريد الإلكتروني'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Add new user
              final newUser = UserModel(
                id: '',
                email: emailController.text.trim(),
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                role: selectedRole,
                createdAt: DateTime.now(),
                status: 'pending',
              );

              setState(() {
                _users.add(newUser);
              });

              Navigator.of(context).pop();

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تمت إضافة المستخدم بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone ?? '');
    UserRole selectedRole = user.role;
    bool isActive = user.status == 'active';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات المستخدم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
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
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'الدور',
                  border: OutlineInputBorder(),
                ),
                items: UserRole.values.map((role) {
                  String label;
                  switch (role) {
                    case UserRole.admin:
                      label = 'مدير';
                      break;
                    case UserRole.client:
                      label = 'عميل';
                      break;
                    case UserRole.worker:
                      label = 'عامل';
                      break;
                    case UserRole.owner:
                      label = 'صاحب عمل';
                      break;
                    case UserRole.accountant:
                      label = 'محاسب';
                      break;
                    case UserRole.manager:
                      label = 'مدير';
                      break;
                    case UserRole.user:
                      label = 'مستخدم';
                      break;
                    case UserRole.pending:
                      label = 'معلق';
                      break;
                  }
                  return DropdownMenuItem<UserRole>(
                    value: role,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedRole = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('مستخدم نشط'),
                value: isActive,
                onChanged: (value) {
                  isActive = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              // Validate input
              if (nameController.text.trim().isEmpty ||
                  emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء إدخال الاسم والبريد الإلكتروني'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Update user
              final index = _users.indexWhere((u) => u.id == user.id);
              if (index != -1) {
                setState(() {
                  final updatedUser = user.copyWith(
                    status: isActive ? 'active' : 'pending',
                    updatedAt: DateTime.now(),
                  );
                  _users[index] = updatedUser;
                });

                Navigator.of(context).pop();

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث بيانات المستخدم بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا المستخدم؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              // Delete user
              setState(() {
                _users.removeWhere((user) => user.id == userId);
              });

              Navigator.of(context).pop();

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف المستخدم بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
