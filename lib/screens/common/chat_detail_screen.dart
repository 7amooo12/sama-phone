import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/user_role.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.role,
  });
  final String chatId;
  final String name;
  final UserRole role;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  // Dummy messages data
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();

    // Set Arabic locale for timeago
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    // Load messages (simulated)
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    // Simulated loading delay
    await Future.delayed(const Duration(seconds: 1));

    // In a real app, we would load messages from Firebase here
    // For now, we'll just set isLoading to false to show the empty state
    setState(() {
      _isLoading = false;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add new message to the list
    setState(() {
      _messages.add({
        'id': const Uuid().v4(),
        'text': text,
        'timestamp': DateTime.now(),
        'senderId': 'current_user',
        'isSent': true,
      });
    });

    // Clear text field
    _messageController.clear();

    // Scroll to the bottom after sending a message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // In a real app, we would send the message to Firebase here
    // and listen for replies from the other user

    // Scroll to the bottom after sending a message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // استخدام مزود Supabase أولاً
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final supabaseUser = supabaseProvider.user;

    // استخدام مزود Auth كإجراء احتياطي
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = supabaseUser ?? authProvider.user;

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
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getRoleColor(widget.role).safeOpacity(0.2),
              child: Text(
                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: _getRoleColor(widget.role),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.name),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey.safeOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لا توجد رسائل',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ابدأ المحادثة الآن',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isSent = message['isSent'] as bool;
                          final timestamp = message['timestamp'] as DateTime;

                          return _buildMessageItem(
                            text: message['text'] as String,
                            isSent: isSent,
                            time: timeago.format(timestamp, locale: 'ar'),
                          );
                        },
                      ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.safeOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                // Message field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                // Send button
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem({
    required String text,
    required bool isSent,
    required String time,
  }) {
    final theme = Theme.of(context);

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSent
              ? theme.colorScheme.primary.safeOpacity(0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSent
                ? theme.colorScheme.primary.safeOpacity(0.2)
                : Colors.grey.safeOpacity(0.2),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
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
}
