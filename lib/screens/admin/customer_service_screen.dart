import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/message_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/chat_provider.dart';
import 'package:smartbiztracker_new/widgets/chat_bubble.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class CustomerServiceScreen extends StatefulWidget {
  const CustomerServiceScreen({super.key});

  @override
  State<CustomerServiceScreen> createState() => _CustomerServiceScreenState();
}

class _CustomerServiceScreenState extends State<CustomerServiceScreen> {
  final TextEditingController _messageController = TextEditingController();
  UserModel? _selectedClient;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Load clients with chats
  void _loadClients() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.user != null) {
      chatProvider.loadUsersWithChats(authProvider.user!.id);
    }
  }

  // Select a client to chat with
  void _selectClient(UserModel client) {
    setState(() {
      _selectedClient = client;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.user != null) {
      chatProvider.loadMessages(
        authProvider.user!.id,
        client.id,
      );
    }

    // Mark all messages as read
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollToBottom();
    });
  }

  // Send a message
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _selectedClient == null) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.user != null) {
      chatProvider.sendMessage(
        senderId: authProvider.user!.id,
        receiverId: _selectedClient!.id,
        content: _messageController.text.trim(),
      );

      _messageController.clear();

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToBottom();
      });
    }
  }

  // Scroll to bottom of chat
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ChatProvider>(
      builder: (context, authProvider, chatProvider, _) {
        final currentUser = authProvider.user;

        return Stack(
          children: [
            Row(
              children: [
                // Clients list
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(
                        right: BorderSide(
                          color: Colors.grey.safeOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.safeOpacity(0.1),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.safeOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.people),
                              SizedBox(width: 8),
                              Text(
                                'العملاء',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Clients list
                        Expanded(
                          child: chatProvider.usersWithChats.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 48,
                                        color: Colors.grey.safeOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'لا توجد محادثات',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: chatProvider.usersWithChats.length,
                                  itemBuilder: (context, index) {
                                    final client =
                                        chatProvider.usersWithChats[index];
                                    final isSelected =
                                        _selectedClient?.id == client.id;

                                    return ListTile(
                                      onTap: () => _selectClient(client),
                                      selected: isSelected,
                                      selectedTileColor: Theme.of(context)
                                          .primaryColor
                                          .safeOpacity(0.1),
                                      leading: CircleAvatar(
                                        backgroundColor: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey.safeOpacity(0.4),
                                        child: Text(
                                          client.name.isNotEmpty
                                              ? client.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(client.name),
                                      subtitle: Text(
                                        client.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Chat area
                Expanded(
                  child: _selectedClient == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat,
                                size: 64,
                                color: Colors.grey.safeOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'اختر عميلًا للبدء في المحادثة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Chat header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.safeOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    child: Text(
                                      _selectedClient!.name.isNotEmpty
                                          ? _selectedClient!.name[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedClient!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedClient!.email,
                                        style: TextStyle(
                                          color: Colors.grey.safeOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Messages area
                            Expanded(
                              child: chatProvider.isLoadingMessages
                                  ? const Center(child: CustomLoader())
                                  : chatProvider.messages.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.chat_bubble_outline,
                                                size: 48,
                                                color: Colors.grey
                                                    .safeOpacity(0.5),
                                              ),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'لا توجد رسائل بعد',
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'ابدأ المحادثة عن طريق إرسال رسالة',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView.builder(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.all(16),
                                          itemCount:
                                              chatProvider.messages.length,
                                          itemBuilder: (context, index) {
                                            final message =
                                                chatProvider.messages[index];
                                            final isSentByMe =
                                                message.senderId ==
                                                    currentUser?.id;

                                            return _buildMessageItem(
                                              message: message,
                                              isSentByMe: isSentByMe,
                                              timestamp: message.timestamp,
                                            );
                                          },
                                        ),
                            ),

                            // Message input
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.grey.safeOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: _messageController,
                                      hintText: 'اكتب رسالتك هنا...',
                                      labelText: 'الرسالة',
                                      onSubmitted: (_) => _sendMessage(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _sendMessage,
                                    icon: const Icon(Icons.send),
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),

            // Loading overlay
            if (chatProvider.isLoading)
              Container(
                color: Colors.black.safeOpacity(0.5),
                child: const Center(
                  child: CustomLoader(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMessageItem({
    required MessageModel message,
    required bool isSentByMe,
    required DateTime timestamp,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ChatBubble(
        message: message.content,
        isMe: isSentByMe,
        timestamp: timestamp,
      ),
    );
  }
}
