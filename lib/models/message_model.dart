import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentType,
    this.messageType = MessageType.text,
    this.metadata,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return MessageModel(
      id: docId ?? map['id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] is String
              ? DateTime.parse(map['timestamp'].toString())
              : DateTime.now()),
      isRead: map['isRead'] as bool? ?? false,
      attachmentUrl: map['attachmentUrl']?.toString(),
      attachmentType: map['attachmentType']?.toString(),
      messageType: map['messageType']?.toString() ?? MessageType.text,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Add fromJson method as an alias for fromMap for consistency
  factory MessageModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return MessageModel.fromMap(json, docId);
  }
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? attachmentUrl;
  final String? attachmentType;
  final String messageType;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'messageType': messageType,
      'metadata': metadata,
    };
  }

  // Add toJson method as an alias for toMap for consistency
  Map<String, dynamic> toJson() => toMap();

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? attachmentUrl,
    String? attachmentType,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
    );
  }
}

class MessageType {
  static const String text = 'TEXT';
  static const String image = 'IMAGE';
  static const String file = 'FILE';
  static const String audio = 'AUDIO';
  static const String location = 'LOCATION';

  static const List<String> values = [text, image, file, audio, location];
}

class AttachmentType {
  static const String image = 'IMAGE';
  static const String pdf = 'PDF';
  static const String doc = 'DOC';
  static const String audio = 'AUDIO';
  static const String other = 'OTHER';

  static const List<String> values = [image, pdf, doc, audio, other];
}
