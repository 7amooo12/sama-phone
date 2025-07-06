import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/chat_model.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/services/enhanced_chat_service.dart';
import 'package:smartbiztracker_new/screens/common/enhanced_chat_screen.dart';
import 'package:smartbiztracker_new/screens/common/new_chat_screen.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';

class EnhancedChatListScreen extends StatefulWidget {
  const EnhancedChatListScreen({super.key});

  @override
  State<EnhancedChatListScreen> createState() => _EnhancedChatListScreenState();
}

class _EnhancedChatListScreenState extends State<EnhancedChatListScreen> {
  final EnhancedChatService _chatService = EnhancedChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final currentUser = supabaseProvider.user;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول أولاً')),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'المحادثات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'new_group':
                  _showCreateGroupDialog(context, currentUser);
                  break;
                case 'archived':
                  _showArchivedChats(context);
                  break;
                case 'settings':
                  _showChatSettings(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (currentUser.userRole == UserRole.admin || currentUser.userRole == UserRole.owner)
                const PopupMenuItem(
                  value: 'new_group',
                  child: Row(
                    children: [
                      Icon(Icons.group_add),
                      SizedBox(width: 8),
                      Text('إنشاء مجموعة'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'archived',
                child: Row(
                  children: [
                    Icon(Icons.archive),
                    SizedBox(width: 8),
                    Text('المحادثات المؤرشفة'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('إعدادات المحادثة'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withOpacity(0.1),
            child: ElegantSearchBar(
              controller: _searchController,
              hintText: 'البحث في المحادثات...',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Chat list
          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              stream: _chatService.getUserChats(currentUser.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'حدث خطأ في تحميل المحادثات',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                final chats = snapshot.data ?? [];
                final filteredChats = _searchQuery.isEmpty
                    ? chats
                    : chats.where((chat) =>
                        (chat.name?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (chat.lastMessage?.content.toLowerCase().contains(_searchQuery) ?? false)
                      ).toList();

                if (filteredChats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.chat_bubble_outline : Icons.search_off,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'لا توجد محادثات بعد'
                              : 'لا توجد نتائج للبحث',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'ابدأ محادثة جديدة مع زملائك'
                              : 'جرب كلمات بحث أخرى',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _navigateToNewChat(context, currentUser),
                            icon: const Icon(Icons.add),
                            label: const Text('بدء محادثة جديدة'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    return _buildChatTile(context, chat, currentUser);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToNewChat(context, currentUser),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ChatModel chat, UserModel currentUser) {
    final theme = Theme.of(context);
    final isUnread = chat.hasUnreadMessages ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isUnread ? 2 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          backgroundImage: chat.avatar != null ? NetworkImage(chat.avatar!) : null,
          child: chat.avatar == null
              ? Icon(
                  (chat.type == 'group' || chat.participants.length > 2) ? Icons.group : Icons.person,
                  color: theme.colorScheme.primary,
                  size: 28,
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chat.name ?? 'محادثة',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(chat.lastMessageTime),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isUnread
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: chat.lastMessage != null
            ? Row(
                children: [
                  if (chat.lastSenderId == currentUser.id)
                    Icon(
                      Icons.done_all,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      chat.lastMessage?.content ?? 'لا توجد رسائل',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isUnread)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        chat.hasUnreadMessages ? '1' : '0',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              )
            : Text(
                'لا توجد رسائل',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
        onTap: () => _navigateToChat(context, chat, currentUser),
        onLongPress: () => _showChatOptions(context, chat, currentUser),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}د';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}س';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}ق';
    } else {
      return 'الآن';
    }
  }

  void _navigateToChat(BuildContext context, ChatModel chat, UserModel currentUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedChatScreen(
          chat: chat,
          currentUser: currentUser,
        ),
      ),
    );
  }

  void _navigateToNewChat(BuildContext context, UserModel currentUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewChatScreen(currentUser: currentUser),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('البحث في المحادثات'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'ابحث عن رسالة أو محادثة...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, UserModel currentUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء مجموعة جديدة'),
        content: const Text('سيتم إضافة هذه الميزة قريباً'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showArchivedChats(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إضافة المحادثات المؤرشفة قريباً')),
    );
  }

  void _showChatSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إضافة إعدادات المحادثة قريباً')),
    );
  }

  void _showChatOptions(BuildContext context, ChatModel chat, UserModel currentUser) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('أرشفة المحادثة'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم أرشفة المحادثة')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_off),
            title: const Text('كتم الإشعارات'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم كتم الإشعارات')),
              );
            },
          ),
          if (currentUser.role == UserRole.admin || currentUser.role == UserRole.owner)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف المحادثة', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _showDeleteConfirmation(context, chat);
              },
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ChatModel chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف محادثة "${chat.name ?? 'هذه المحادثة'}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف المحادثة')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
