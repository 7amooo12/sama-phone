import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../utils/logger.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all chats for a user
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Get admin chats
  Stream<List<ChatModel>> getAdminChats() {
    return _firestore
        .collection('chats')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Create a new chat
  Future<String> createChat(ChatModel chat) async {
    try {
      final docRef = await _firestore.collection('chats').add(chat.toMap());
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error creating chat', e);
      throw Exception('Failed to create chat');
    }
  }

  // Update a chat
  Future<void> updateChat(ChatModel chat) async {
    try {
      await _firestore.collection('chats').doc(chat.id).update(chat.toMap());
    } catch (e) {
      AppLogger.error('Error updating chat', e);
      throw Exception('Failed to update chat');
    }
  }

  // Add message to chat
  Future<void> addMessage(String chatId, MessageModel message) async {
    try {
      // Get the current chat document
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) throw Exception('Chat not found');

      // Create a new message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      // Update the chat's lastMessage and lastMessageAt
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message.toMap(),
        'lastMessageAt': message.timestamp,
      });
    } catch (e) {
      AppLogger.error('Error adding message', e);
      throw Exception('Failed to add message');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Get unread messages for this user from the subcollection
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      // Update each message
      final batch = _firestore.batch();
      for (final messageDoc in messagesQuery.docs) {
        batch.update(messageDoc.reference, {'isRead': true});
      }

      // Commit the batch
      await batch.commit();

      // Also update the lastReadTimestamp for this user
      await _firestore.collection('chats').doc(chatId).update({
        'lastReadTimestamp.$userId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error marking messages as read', e);
      throw Exception('Failed to mark messages as read');
    }
  }

  // Mark chat as resolved
  Future<void> resolveChatSession(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'metadata.isResolved': true,
      });
    } catch (e) {
      AppLogger.error('Error resolving chat', e);
      throw Exception('Failed to resolve chat');
    }
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    try {
      // Delete all messages in the subcollection first
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document itself
      batch.delete(_firestore.collection('chats').doc(chatId));

      await batch.commit();
    } catch (e) {
      AppLogger.error('Error deleting chat', e);
      throw Exception('Failed to delete chat');
    }
  }

  // Get unread messages count
  Future<int> getUnreadMessagesCount(String userId) async {
    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      int count = 0;

      for (final chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .where('receiverId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .count()
            .get();

        // Converting to non-nullable int with 0 as fallback
        count += messagesSnapshot.count ?? 0;
      }

      return count;
    } catch (e) {
      AppLogger.error('Error getting unread messages count', e);
      return 0;
    }
  }
}
