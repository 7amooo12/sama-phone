import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
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
import 'package:smartbiztracker_new/widgets/common/loading_overlay.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUsers();
      }
    });
  }

  // استدعاء المستخدمين من Firestore
  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AppLogger.info('Loading users in UserManagementScreen');
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

      // استدعاء جميع المستخدمين من SupabaseProvider
      final users = await supabaseProvider.getAllUsers();

      if (mounted) {
        setState(() {
          _users = users;
        });
        AppLogger.info('Successfully loaded ${_users.length} users');

        // Log user roles for debugging
        final roleCount = <String, int>{};
        for (final user in _users) {
          final role = user.role.value;
          roleCount[role] = (roleCount[role] ?? 0) + 1;
        }
        AppLogger.info('User roles: ${roleCount.entries.map((e) => '${e.key}: ${e.value}').join(', ')}');
      }
    } catch (e) {
      AppLogger.error('Error loading users: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تحميل المستخدمين: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      AppLogger.warning('User not logged in, redirecting to login');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // التحقق من صلاحيات المستخدم
    if (!userModel.isAdmin()) {
      AppLogger.warning('User ${userModel.email} is not admin, redirecting to dashboard');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ليس لديك صلاحية للوصول إلى هذه الصفحة'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
      if (pendingOnly) {
        // Show only pending users (not approved yet)
        if (user.isApproved) return false;
      }

      // Filter by role if specified
      if (filterRole != null) {
        if (user.role != filterRole) {
          // Include workers and owners if needed
          if (includeWorkers && user.role == UserRole.worker) {
            // Include workers - allow them to pass
          } else if (includeOwners && user.role == UserRole.owner) {
            // Include owners - allow them to pass
          } else if (includeWorkers && user.role == UserRole.accountant) {
            // Include accountants in users tab - allow them to pass
          } else if (includeWorkers && user.role == UserRole.employee) {
            // Include employees in users tab - allow them to pass
          } else if (includeWorkers && user.role == UserRole.manager) {
            // Include managers in users tab - allow them to pass
          } else {
            return false; // Exclude this user
          }
        }
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            (user.phone.contains(query));
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
                                      if (!user.isApproved)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.safeOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'بانتظار الموافقة',
                                            style: TextStyle(
                                              color: Colors.orange,
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
                            if (!user.isApproved)
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
      case UserRole.employee:
        color = Colors.indigo;
        text = 'موظف';
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
      case UserRole.warehouseManager:
        color = Colors.brown;
        text = 'مدير المخزن';
        break;
      case UserRole.user:
        color = Colors.grey;
        text = 'مستخدم';
        break;
      case UserRole.guest:
        color = Colors.blueGrey;
        text = 'زائر';
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
      case UserRole.employee:
        return Colors.indigo;
      case UserRole.accountant:
        return Colors.orange;
      case UserRole.client:
        return Colors.purple;
      case UserRole.manager:
        return Colors.teal;
      case UserRole.warehouseManager:
        return Colors.brown;
      case UserRole.user:
        return Colors.grey;
      case UserRole.guest:
        return Colors.blueGrey;
      case UserRole.pending:
        return Colors.brown;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _approveUser(String userId) async {
    try {
      setState(() => _isLoading = true);

      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

      // Approve user in database
      final success = await supabaseProvider.approveUser(userId);

      if (success) {
        // Update local list
        final index = _users.indexWhere((user) => user.id == userId);
        if (index != -1) {
          setState(() {
            _users[index] = _users[index].copyWith(
              isApproved: true,
              updatedAt: DateTime.now(),
            );
          });
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تمت الموافقة على المستخدم بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(supabaseProvider.error ?? 'فشل في الموافقة على المستخدم'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error approving user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء الموافقة على المستخدم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                    case UserRole.employee:
                      label = 'موظف';
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
                    case UserRole.warehouseManager:
                      label = 'مدير المخزن';
                      break;
                    case UserRole.user:
                      label = 'مستخدم';
                      break;
                    case UserRole.guest:
                      label = 'زائر';
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
            onPressed: () async {
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

              // Validate email format
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text.trim())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('البريد الإلكتروني غير صحيح'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                setState(() => _isLoading = true);

                final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

                // Create user in database
                final success = await supabaseProvider.createUser(
                  email: emailController.text.trim(),
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  role: selectedRole,
                );

                if (success) {
                  // Reload users list
                  await _loadUsers();

                  Navigator.of(context).pop();

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة المستخدم بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(supabaseProvider.error ?? 'فشل في إضافة المستخدم'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                AppLogger.error('Error adding user: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('حدث خطأ أثناء إضافة المستخدم'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
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
    bool isActive = user.isApproved;

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
                    case UserRole.employee:
                      label = 'موظف';
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
                    case UserRole.warehouseManager:
                      label = 'مدير المخزن';
                      break;
                    case UserRole.user:
                      label = 'مستخدم';
                      break;
                    case UserRole.guest:
                      label = 'زائر';
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
            onPressed: () async {
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

              // Validate email format
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text.trim())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('البريد الإلكتروني غير صحيح'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                setState(() => _isLoading = true);

                final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

                // Update user in database
                final success = await supabaseProvider.updateUser(
                  userId: user.id,
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  role: selectedRole,
                  isApproved: isActive,
                );

                if (success) {
                  // Update local list
                  final index = _users.indexWhere((u) => u.id == user.id);
                  if (index != -1) {
                    setState(() {
                      _users[index] = user.copyWith(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                        role: selectedRole,
                        isApproved: isActive,
                        updatedAt: DateTime.now(),
                      );
                    });
                  }

                  Navigator.of(context).pop();

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث بيانات المستخدم بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(supabaseProvider.error ?? 'فشل في تحديث المستخدم'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                AppLogger.error('Error updating user: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('حدث خطأ أثناء تحديث المستخدم'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
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
            onPressed: () async {
              try {
                setState(() => _isLoading = true);

                final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

                // Delete user from database
                final success = await supabaseProvider.deleteUser(userId);

                if (success) {
                  // Remove from local list
                  setState(() {
                    _users.removeWhere((user) => user.id == userId);
                  });

                  Navigator.of(context).pop();

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حذف المستخدم بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  Navigator.of(context).pop();

                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(supabaseProvider.error ?? 'فشل في حذف المستخدم'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                AppLogger.error('Error deleting user: $e');
                Navigator.of(context).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('حدث خطأ أثناء حذف المستخدم'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
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
