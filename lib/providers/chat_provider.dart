import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _usersWithChats = [];
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMessages = false;

  List<UserModel> get usersWithChats => _usersWithChats;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;

  Future<void> loadUsersWithChats(String currentUserId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      final userIds = snapshot.docs
          .expand((doc) => (doc.data()['participants'] as List).cast<String>())
          .where((id) => id != currentUserId)
          .toSet()
          .toList();

      if (userIds.isNotEmpty) {
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: userIds)
            .get();

        _usersWithChats = usersSnapshot.docs
            .map((doc) => UserModel.fromMap({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList();
      } else {
        _usersWithChats = [];
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String currentUserId, String otherUserId) async {
    try {
      _isLoadingMessages = true;
      notifyListeners();

      final chatId = _getChatId(currentUserId, otherUserId);

      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      _messages = messagesSnapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      rethrow;
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final chatId = _getChatId(senderId, receiverId);
      final message = MessageModel(
        id: '', // Will be set by Firestore
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
      );

      final doc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      final updatedMessage = message.copyWith(id: doc.id);
      _messages.insert(0, updatedMessage);

      // Ensure chat document exists with participants
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [senderId, receiverId],
        'lastMessage': content,
        'lastMessageTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markMessageAsRead({required String messageId}) async {
    try {
      final message = _messages.firstWhere((msg) => msg.id == messageId);
      final chatId = _getChatId(message.senderId, message.receiverId);

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});

      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        _messages[index] = message.copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  String _getChatId(String userId1, String userId2) {
    // Create a consistent chat ID by sorting user IDs
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }
}
