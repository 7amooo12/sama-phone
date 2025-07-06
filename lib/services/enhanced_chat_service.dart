import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../utils/logger.dart';

class EnhancedChatService {
  factory EnhancedChatService() => _instance;
  EnhancedChatService._internal();
  static final EnhancedChatService _instance = EnhancedChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  static const String _chatsCollection = 'chats';
  static const String _messagesCollection = 'messages';
  static const String _usersCollection = 'users';

  /// Get available users for chat based on current user role
  Future<List<UserModel>> getAvailableUsersForChat(UserRole currentUserRole, String currentUserId) async {
    try {
      Query query = _firestore.collection(_usersCollection);

      // Apply role-based filtering
      switch (currentUserRole) {
        case UserRole.client:
          // Clients can only chat with admin and accountant
          query = query.where('userRole', whereIn: ['admin', 'accountant']);
          break;
        case UserRole.admin:
        case UserRole.owner:
        case UserRole.manager:
          // Admin, Owner, Manager can chat with everyone except other clients
          query = query.where('userRole', whereNotIn: ['client']);
          break;
        case UserRole.worker:
        case UserRole.employee:
        case UserRole.accountant:
          // Workers, Employees, Accountants can chat with everyone except clients
          query = query.where('userRole', whereNotIn: ['client']);
          break;
        default:
          // Default: no access
          return [];
      }

      // Exclude current user
      query = query.where('id', isNotEqualTo: currentUserId);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting available users for chat: $e');
      return [];
    }
  }

  /// Check if user can start chat with another user
  bool canStartChatWith(UserRole currentUserRole, UserRole targetUserRole) {
    switch (currentUserRole) {
      case UserRole.client:
        // Clients can only chat with admin and accountant
        return targetUserRole == UserRole.admin || targetUserRole == UserRole.accountant;
      case UserRole.admin:
      case UserRole.owner:
      case UserRole.manager:
        // Admin, Owner, Manager can chat with everyone except other clients
        return targetUserRole != UserRole.client;
      case UserRole.worker:
      case UserRole.employee:
      case UserRole.accountant:
        // Workers, Employees, Accountants can chat with everyone except clients
        return targetUserRole != UserRole.client;
      default:
        return false;
    }
  }

  /// Get or create a direct chat between two users
  Future<String?> getOrCreateDirectChat(String currentUserId, String targetUserId, String targetUserName) async {
    try {
      // Check if chat already exists
      final existingChat = await _firestore
          .collection(_chatsCollection)
          .where('type', isEqualTo: ChatType.direct)
          .where('participants', arrayContains: currentUserId)
          .get();

      for (final doc in existingChat.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        if (participants.contains(targetUserId) && participants.length == 2) {
          return doc.id;
        }
      }

      // Create new chat
      final chatRef = _firestore.collection(_chatsCollection).doc();
      final now = DateTime.now();

      await chatRef.set({
        'type': ChatType.direct,
        'name': targetUserName, // Set the target user's name as chat name
        'participants': [currentUserId, targetUserId],
        'createdAt': Timestamp.fromDate(now),
        'createdBy': currentUserId,
        'lastMessageTime': Timestamp.fromDate(now),
        'metadata': {},
        'lastReadTimestamp': {
          currentUserId: Timestamp.fromDate(now),
          targetUserId: Timestamp.fromDate(now),
        },
        'isArchived': false,
        'isMuted': false,
        'isPinned': false,
      });

      return chatRef.id;
    } catch (e) {
      AppLogger.error('Error creating direct chat: $e');
      return null;
    }
  }

  /// Get user's chats with enhanced data
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection(_chatsCollection)
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<ChatModel> chats = [];
      
      for (final doc in snapshot.docs) {
        final chatData = doc.data();
        final participants = List<String>.from(chatData['participants']);
        
        // For direct chats, get the other participant's info
        if (chatData['type'] == ChatType.direct && participants.length == 2) {
          final otherUserId = participants.firstWhere((id) => id != userId);
          final userDoc = await _firestore.collection(_usersCollection).doc(otherUserId).get();
          
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            chatData['name'] = userData['name'] ?? 'مستخدم';
            chatData['avatar'] = userData['avatar'];
          }
        }
        
        // Calculate unread count
        final unreadCount = await getUnreadMessageCount(doc.id, userId);
        chatData['hasUnreadMessages'] = unreadCount > 0;
        
        chats.add(ChatModel.fromJson(chatData, doc.id));
      }
      
      return chats;
    });
  }

  /// Send a message with enhanced features
  Future<bool> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String content,
    required MessageType type,
    String? replyToMessageId,
    List<String>? attachments,
  }) async {
    try {
      final messageRef = _firestore.collection(_messagesCollection).doc();
      final now = DateTime.now();

      final messageData = {
        'id': messageRef.id,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole.toString(),
        'content': content,
        'type': type.toString(),
        'timestamp': Timestamp.fromDate(now),
        'status': MessageStatus.sent.toString(),
        'replyToMessageId': replyToMessageId,
        'attachments': attachments,
      };

      // Add message to messages collection
      await messageRef.set(messageData);

      // Update chat's last message
      await _firestore.collection(_chatsCollection).doc(chatId).update({
        'lastMessageTime': Timestamp.fromDate(now),
        'lastMessageContent': content,
        'lastSenderId': senderId,
        'lastMessage': messageData,
      });

      return true;
    } catch (e) {
      AppLogger.error('Error sending message: $e');
      return false;
    }
  }

  /// Get messages for a chat with pagination
  Stream<List<MessageModel>> getChatMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection(_messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      await _firestore.collection(_chatsCollection).doc(chatId).update({
        'lastReadTimestamp.$userId': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      AppLogger.error('Error marking messages as read: $e');
    }
  }

  /// Get unread message count for a chat
  Future<int> getUnreadMessageCount(String chatId, String userId) async {
    try {
      final chatDoc = await _firestore.collection(_chatsCollection).doc(chatId).get();
      if (!chatDoc.exists) return 0;

      final chatData = chatDoc.data()!;
      final lastReadTimestamp = chatData['lastReadTimestamp']?[userId] as Timestamp?;
      
      if (lastReadTimestamp == null) return 0;

      final unreadMessages = await _firestore
          .collection(_messagesCollection)
          .where('chatId', isEqualTo: chatId)
          .where('senderId', isNotEqualTo: userId)
          .where('timestamp', isGreaterThan: lastReadTimestamp)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      AppLogger.error('Error getting unread message count: $e');
      return 0;
    }
  }

  /// Create a group chat (for admin/owner only)
  Future<String?> createGroupChat({
    required String creatorId,
    required String groupName,
    required List<String> participants,
    String? description,
  }) async {
    try {
      final chatRef = _firestore.collection(_chatsCollection).doc();
      final now = DateTime.now();

      await chatRef.set({
        'type': ChatType.group,
        'name': groupName,
        'description': description,
        'participants': participants,
        'admins': [creatorId],
        'createdAt': Timestamp.fromDate(now),
        'createdBy': creatorId,
        'lastMessageTime': Timestamp.fromDate(now),
        'metadata': {},
        'lastReadTimestamp': {
          for (String participant in participants)
            participant: Timestamp.fromDate(now),
        },
        'isArchived': false,
        'isMuted': false,
        'isPinned': false,
      });

      return chatRef.id;
    } catch (e) {
      AppLogger.error('Error creating group chat: $e');
      return null;
    }
  }

  /// Delete a message (sender only or admin)
  Future<bool> deleteMessage(String messageId, String userId, UserRole userRole) async {
    try {
      final messageDoc = await _firestore.collection(_messagesCollection).doc(messageId).get();
      if (!messageDoc.exists) return false;

      final messageData = messageDoc.data()!;
      final senderId = messageData['senderId'] as String;

      // Check if user can delete (sender or admin/owner)
      if (senderId == userId || userRole == UserRole.admin || userRole == UserRole.owner) {
        await _firestore.collection(_messagesCollection).doc(messageId).delete();
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error deleting message: $e');
      return false;
    }
  }

  /// Search messages in a chat
  Future<List<MessageModel>> searchMessages(String chatId, String query) async {
    try {
      final messages = await _firestore
          .collection(_messagesCollection)
          .where('chatId', isEqualTo: chatId)
          .where('content', isGreaterThanOrEqualTo: query)
          .where('content', isLessThanOrEqualTo: '$query\uf8ff')
          .orderBy('content')
          .orderBy('timestamp', descending: true)
          .get();

      return messages.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      AppLogger.error('Error searching messages: $e');
      return [];
    }
  }
}

// Message types for enhanced chat
enum MessageType {
  text,
  image,
  file,
  voice,
  location,
  system;

  @override
  String toString() {
    return name;
  }

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (type) => type.toString() == value,
      orElse: () => MessageType.text,
    );
  }
}

// Message status for delivery tracking
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  @override
  String toString() {
    return name;
  }

  static MessageStatus fromString(String value) {
    return MessageStatus.values.firstWhere(
      (status) => status.toString() == value,
      orElse: () => MessageStatus.sent,
    );
  }
}
