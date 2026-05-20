import 'user.dart';

class MessageReaction {
  final String userId;
  final String emoji;

  MessageReaction({required this.userId, required this.emoji});

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: json['userId']?.toString() ?? '',
      emoji: json['emoji'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'userId': userId, 'emoji': emoji};
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final String image;
  // Document fields
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String fileExt;
  // Call fields
  final String callType;   // 'voice_call' | 'video_call' | ''
  final String callStatus; // 'missed' | 'declined' | 'ended' | ''
  final int callDuration;  // seconds
  final bool seen;
  final bool delivered;
  final DateTime createdAt;
  final User? sender;
  final bool deletedForEveryone;
  final List<String> deletedFor;
  final List<MessageReaction> reactions;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text = '',
    this.image = '',
    this.fileUrl = '',
    this.fileName = '',
    this.fileSize = 0,
    this.fileExt = '',
    this.callType = '',
    this.callStatus = '',
    this.callDuration = 0,
    this.seen = false,
    this.delivered = false,
    required this.createdAt,
    this.sender,
    this.deletedForEveryone = false,
    this.deletedFor = const [],
    this.reactions = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      chatId: json['chatId']?.toString() ?? '',
      senderId: json['senderId']?['_id'] ?? json['senderId'] ?? '',
      text: json['text'] ?? '',
      image: json['image'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      fileExt: json['fileExt'] ?? '',
      callType: json['callType'] ?? '',
      callStatus: json['callStatus'] ?? '',
      callDuration: json['callDuration'] ?? 0,
      seen: json['seen'] ?? false,
      delivered: json['delivered'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      sender: json['senderId'] != null && json['senderId'] is Map
          ? User.fromJson(json['senderId'])
          : null,
      deletedForEveryone: json['deletedForEveryone'] ?? false,
      deletedFor: json['deletedFor'] != null
          ? List<String>.from(
              (json['deletedFor'] as List).map((e) => e.toString()))
          : [],
      reactions: json['reactions'] != null
          ? List<MessageReaction>.from(
              (json['reactions'] as List).map((r) => MessageReaction.fromJson(r)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'image': image,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileExt': fileExt,
      'callType': callType,
      'callStatus': callStatus,
      'callDuration': callDuration,
      'seen': seen,
      'delivered': delivered,
      'createdAt': createdAt.toIso8601String(),
      'deletedForEveryone': deletedForEveryone,
      'deletedFor': deletedFor,
      'reactions': reactions.map((r) => r.toJson()).toList(),
    };
  }

  bool get isImage => image.isNotEmpty;
  bool get isDocument => fileUrl.isNotEmpty && fileUrl.isNotEmpty;
  bool get isCall => callType.isNotEmpty;

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    String? image,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileExt,
    String? callType,
    String? callStatus,
    int? callDuration,
    bool? seen,
    bool? delivered,
    DateTime? createdAt,
    User? sender,
    bool? deletedForEveryone,
    List<String>? deletedFor,
    List<MessageReaction>? reactions,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      image: image ?? this.image,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileExt: fileExt ?? this.fileExt,
      callType: callType ?? this.callType,
      callStatus: callStatus ?? this.callStatus,
      callDuration: callDuration ?? this.callDuration,
      seen: seen ?? this.seen,
      delivered: delivered ?? this.delivered,
      createdAt: createdAt ?? this.createdAt,
      sender: sender ?? this.sender,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedFor: deletedFor ?? this.deletedFor,
      reactions: reactions ?? this.reactions,
    );
  }
}
