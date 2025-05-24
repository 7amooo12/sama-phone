import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/chat_provider.dart';
import 'package:smartbiztracker_new/widgets/chat_bubble.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class CustomerServiceScreen extends StatefulWidget {
  const CustomerServiceScreen({super.key});

  @override
  State<CustomerServiceScreen> createState() => _CustomerServiceScreenState();
}

class _CustomerServiceScreenState extends State<CustomerServiceScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChat();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Load chat with admin
  void _loadChat() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.user != null) {
      // For clients, we'll use a hard-coded admin ID for now
      // In a real app, you'd fetch this from your backend
      const String adminId = 'admin_user_id';

      chatProvider.loadMessages(
        authProvider.user!.id,
        adminId,
      );
    }
  }

  // Send a message
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.user != null) {
      // For clients, we'll use a hard-coded admin ID for now
      const String adminId = 'admin_user_id';

      chatProvider.sendMessage(
        senderId: authProvider.user!.id,
        receiverId: adminId,
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
            Column(
              children: [
                // Chat header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.safeOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(
                          Icons.support_agent,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'خدمة العملاء',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text('تواصل مباشر مع فريق الدعم'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat messages
                Expanded(
                  child: chatProvider.messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 200,
                                width: 200,
                                child: Lottie.network(
                                  'https://assets9.lottiefiles.com/packages/lf20_urbk83vw.json',
                                  repeat: true,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'ابدأ المحادثة الآن',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'فريق خدمة العملاء متاح للرد على استفساراتك',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: () => FocusScope.of(context).unfocus(),
                          child: AnimationLimiter(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              reverse: true,
                              itemCount: chatProvider.messages.length,
                              itemBuilder: (context, index) {
                                final message = chatProvider.messages[index];
                                final bool isMe =
                                    message.senderId == currentUser?.id;
                                final DateFormat timeFormat =
                                    DateFormat('hh:mm a');
                                final String timeString =
                                    timeFormat.format(message.timestamp);

                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 375),
                                  child: SlideAnimation(
                                    horizontalOffset: isMe ? 50.0 : -50.0,
                                    child: FadeInAnimation(
                                      child: ChatBubble(
                                        message: message.content,
                                        isMe: isMe,
                                        timestamp: message.timestamp,
                                        isRead: message.isRead,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),

                // Message input
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _messageController,
                          labelText: 'رسالة',
                          hintText: 'اكتب رسالتك هنا...',
                          prefixIcon: Icons.message,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        radius: 24,
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Loading indicator
            if (chatProvider.isLoading) const CustomLoader(),
          ],
        );
      },
    );
  }
}
