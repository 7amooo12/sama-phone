import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/services/enhanced_chat_service.dart';
import 'package:smartbiztracker_new/screens/common/enhanced_chat_screen.dart';
import 'package:smartbiztracker_new/models/chat_model.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';

class NewChatScreen extends StatefulWidget {

  const NewChatScreen({
    super.key,
    required this.currentUser,
  });
  final UserModel currentUser;

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final EnhancedChatService _chatService = EnhancedChatService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _availableUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _chatService.getAvailableUsersForChat(
        widget.currentUser.role,
        widget.currentUser.id,
      );
      
      setState(() {
        _availableUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المستخدمين: $e')),
        );
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUsers = _availableUsers;
      } else {
        _filteredUsers = _availableUsers
            .where((user) =>
                user.name.toLowerCase().contains(query.toLowerCase()) ||
                user.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _startChat(UserModel targetUser) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get or create chat
      final chatId = await _chatService.getOrCreateDirectChat(
        widget.currentUser.id,
        targetUser.id,
        targetUser.name,
      );

      // Hide loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (chatId != null) {
        // Create chat model for navigation
        final chat = ChatModel(
          id: chatId,
          type: ChatType.direct,
          participants: [widget.currentUser.id, targetUser.id],
          name: targetUser.name,
          metadata: {},
          createdAt: DateTime.now(),
          createdBy: widget.currentUser.id,
          lastReadTimestamp: {},
          isArchived: false,
          isMuted: false,
          isPinned: false,
          lastMessageTime: DateTime.now(),
        );

        // Navigate to chat screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(
                chat: chat,
                currentUser: widget.currentUser,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل في إنشاء المحادثة')),
          );
        }
      }
    } catch (e) {
      // Hide loading
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء المحادثة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'بدء محادثة جديدة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: ElegantSearchBar(
              controller: _searchController,
              hintText: 'البحث عن مستخدم...',
              onChanged: _filterUsers,
            ),
          ),

          // User role info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'يمكنك التواصل مع:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getAvailableRolesText(widget.currentUser.role),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                              size: 64,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'لا يوجد مستخدمون متاحون'
                                  : 'لا توجد نتائج للبحث',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'لا يوجد مستخدمون يمكنك التواصل معهم حالياً'
                                  : 'جرب كلمات بحث أخرى',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserTile(context, user, theme);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
          backgroundImage: user.profileImage != null ? NetworkImage(user.profileImage!) : null,
          child: user.profileImage == null
              ? Icon(
                  Icons.person,
                  color: _getRoleColor(user.role),
                  size: 24,
                )
              : null,
        ),
        title: Text(
          user.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRoleDisplayName(user.role),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chat_bubble_outline,
          color: theme.colorScheme.primary,
        ),
        onTap: () => _startChat(user),
      ),
    );
  }

  String _getAvailableRolesText(UserRole currentRole) {
    switch (currentRole) {
      case UserRole.client:
        return 'الإدارة والمحاسبة فقط';
      case UserRole.admin:
      case UserRole.owner:
      case UserRole.manager:
        return 'جميع الموظفين والإدارة (عدا العملاء)';
      case UserRole.worker:
      case UserRole.employee:
      case UserRole.accountant:
        return 'جميع الموظفين والإدارة (عدا العملاء)';
      default:
        return 'غير محدد';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Colors.purple;
      case UserRole.admin:
        return Colors.red;
      case UserRole.manager:
        return Colors.blue;
      case UserRole.accountant:
        return Colors.green;
      case UserRole.worker:
      case UserRole.employee:
        return Colors.orange;
      case UserRole.client:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'صاحب العمل';
      case UserRole.admin:
        return 'مدير';
      case UserRole.manager:
        return 'مشرف';
      case UserRole.accountant:
        return 'محاسب';
      case UserRole.worker:
        return 'عامل';
      case UserRole.employee:
        return 'موظف';
      case UserRole.client:
        return 'عميل';
      default:
        return 'غير محدد';
    }
  }
}
