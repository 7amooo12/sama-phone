import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/user_role.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;

  // Empty chat list - will be populated with real data from Firebase
  final List<Map<String, dynamic>> _chatList = [];

  @override
  void initState() {
    super.initState();

    // Simulate loading chat list
    Future.delayed(const Duration(seconds: 1)).then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    // Set Arabic locale for timeago
    timeago.setLocaleMessages('ar', timeago.ArMessages());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

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

    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'المحادثات',
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: AppRoutes.chatList,
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _chatList.isEmpty
              ? _buildEmptyState()
              : _buildChatList(theme),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to new chat screen or show user list to start a chat
          _showNewChatDialog();
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 16),
          const Text('جاري تحميل المحادثات...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty_chat.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد محادثات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ابدأ محادثة جديدة بالضغط على زر (+) أدناه',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(ThemeData theme) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _chatList.length,
        itemBuilder: (context, index) {
          final chat = _chatList[index];
          final time =
              timeago.format(chat['timestamp'] as DateTime, locale: 'ar');

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      // Navigate to chat detail screen
                      Navigator.of(context).pushNamed(
                        AppRoutes.chatDetail,
                        arguments: {
                          'chatId': chat['id'] as String,
                          'name': chat['name'] as String,
                          'role': chat['role'] as UserRole,
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _buildUserAvatar(chat),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      chat['name'].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .safeOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        chat['lastMessage'].toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              (chat['unreadCount'] as int) > 0
                                                  ? theme.colorScheme.onSurface
                                                  : theme.colorScheme.onSurface
                                                      .safeOpacity(0.7),
                                          fontWeight:
                                              (chat['unreadCount'] as int) > 0
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if ((chat['unreadCount'] as int) > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          chat['unreadCount'].toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildUserAvatar(Map<String, dynamic> chat) {
    final role = chat['role'] as UserRole;
    final avatarColor = _getRoleColor(role);

    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: avatarColor.safeOpacity(0.2),
          backgroundImage: chat['avatarUrl'] != null
              ? NetworkImage(chat['avatarUrl'].toString())
              : null,
          child: chat['avatarUrl'] == null
              ? Text(
                  chat['name'][0].toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: avatarColor,
                  ),
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _getRoleColor(role),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: Icon(
              _getRoleIcon(role),
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  bool _canAccessChat(String userRole) {
    final role = UserRole.fromString(userRole);
    switch (role) {
      case UserRole.admin:
      case UserRole.owner:
      case UserRole.client:
      case UserRole.worker:
      case UserRole.employee:
      case UserRole.accountant:
      case UserRole.manager:
      case UserRole.warehouseManager:
        return true;
      case UserRole.user:
      case UserRole.guest:
      case UserRole.pending:
        return false;
    }
  }

  String _getRoleText(UserRole role) {
    return role.displayName;
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.owner:
        return Colors.blue;
      case UserRole.client:
        return Colors.green;
      case UserRole.worker:
        return Colors.orange;
      case UserRole.employee:
        return Colors.indigo;
      case UserRole.accountant:
        return Colors.purple;
      case UserRole.manager:
        return Colors.teal;
      case UserRole.warehouseManager:
        return Colors.brown;
      case UserRole.user:
      case UserRole.guest:
      case UserRole.pending:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.client:
        return Icons.person;
      case UserRole.worker:
        return Icons.engineering;
      case UserRole.employee:
        return Icons.work;
      case UserRole.owner:
        return Icons.business;
      case UserRole.accountant:
        return Icons.calculate;
      case UserRole.manager:
        return Icons.manage_accounts;
      case UserRole.warehouseManager:
        return Icons.warehouse;
      case UserRole.user:
      case UserRole.guest:
      case UserRole.pending:
        return Icons.person_outline;
    }
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بدء محادثة جديدة'),
        content: const Text('اختر مستخدم للدردشة معه'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to user selection screen
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }
}
