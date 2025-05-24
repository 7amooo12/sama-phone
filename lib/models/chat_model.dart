import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';

class ChatModel {
  ChatModel({
    required this.id,
    required this.type,
    required this.participants,
    this.name,
    this.description,
    this.avatar,
    required this.metadata,
    required this.createdAt,
    required this.createdBy,
    this.lastMessageAt,
    this.lastMessage,
    required this.lastReadTimestamp,
    required this.isArchived,
    required this.isMuted,
    required this.isPinned,
    this.admins,
    required this.lastMessageTime,
    this.lastMessageContent,
    this.lastSenderId,
    this.hasUnreadMessages = false,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return ChatModel.fromJson(map, docId);
  }

  factory ChatModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return ChatModel(
      id: docId ?? json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      avatar: json['avatar']?.toString(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : {},
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now()),
      createdBy: json['createdBy']?.toString() ?? '',
      lastMessageAt: json['lastMessageAt'] != null
          ? (json['lastMessageAt'] is Timestamp
              ? (json['lastMessageAt'] as Timestamp).toDate()
              : (json['lastMessageAt'] is String
                  ? DateTime.parse(json['lastMessageAt'] as String)
                  : null))
          : null,
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromMap(
              Map<String, dynamic>.from(json['lastMessage'] as Map),
              json['lastMessage']['id']?.toString() ?? '')
          : null,
      lastReadTimestamp: json['lastReadTimestamp'] != null
          ? (json['lastReadTimestamp'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                  key,
                  value is Timestamp
                      ? value.toDate()
                      : (value is String
                          ? DateTime.parse(value)
                          : DateTime.now())),
            )
          : {},
      isArchived: json['isArchived'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      admins:
          (json['admins'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      lastMessageTime: json['lastMessageTime'] != null
          ? (json['lastMessageTime'] is Timestamp
              ? (json['lastMessageTime'] as Timestamp).toDate()
              : (json['lastMessageTime'] is DateTime
                  ? json['lastMessageTime'] as DateTime
                  : DateTime.tryParse(json['lastMessageTime'].toString()) ??
                      DateTime.now()))
          : DateTime.now(),
      lastMessageContent: json['lastMessageContent']?.toString(),
      lastSenderId: json['lastSenderId']?.toString(),
      hasUnreadMessages: json['hasUnreadMessages'] as bool? ?? false,
    );
  }
  final String id;
  final String type;
  final List<String> participants;
  final String? name;
  final String? description;
  final String? avatar;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? lastMessageAt;
  final MessageModel? lastMessage;
  final Map<String, DateTime> lastReadTimestamp;
  final bool isArchived;
  final bool isMuted;
  final bool isPinned;
  final List<String>? admins;
  final DateTime lastMessageTime;
  final String? lastMessageContent;
  final String? lastSenderId;
  final bool hasUnreadMessages;

  ChatModel copyWith({
    String? id,
    String? type,
    List<String>? participants,
    String? name,
    String? description,
    String? avatar,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    String? createdBy,
    DateTime? lastMessageAt,
    MessageModel? lastMessage,
    Map<String, DateTime>? lastReadTimestamp,
    bool? isArchived,
    bool? isMuted,
    bool? isPinned,
    List<String>? admins,
    DateTime? lastMessageTime,
    String? lastMessageContent,
    String? lastSenderId,
    bool? hasUnreadMessages,
  }) {
    return ChatModel(
      id: id ?? this.id,
      type: type ?? this.type,
      participants: participants ?? this.participants,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastReadTimestamp: lastReadTimestamp ?? this.lastReadTimestamp,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      admins: admins ?? this.admins,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'participants': participants,
      'name': name,
      'description': description,
      'avatar': avatar,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'lastMessage': lastMessage?.toMap(),
      'lastReadTimestamp': lastReadTimestamp.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'isArchived': isArchived,
      'isMuted': isMuted,
      'isPinned': isPinned,
      'admins': admins,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessageContent': lastMessageContent,
      'lastSenderId': lastSenderId,
      'hasUnreadMessages': hasUnreadMessages,
    };
  }

  Map<String, dynamic> toMap() => toJson();
}

class ChatType {
  static const String direct = 'DIRECT';
  static const String group = 'GROUP';
  static const String channel = 'CHANNEL';
  static const String support = 'SUPPORT';

  static const List<String> values = [direct, group, channel, support];
}
