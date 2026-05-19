import 'user.dart';

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final String image;
  final bool seen;
  final bool delivered;
  final DateTime createdAt;
  final User? sender;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text = '',
    this.image = '',
    this.seen = false,
    this.delivered = false,
    required this.createdAt,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      chatId: json['chatId'] ?? '',
      senderId: json['senderId']?['_id'] ?? json['senderId'] ?? '',
      text: json['text'] ?? '',
      image: json['image'] ?? '',
      seen: json['seen'] ?? false,
      delivered: json['delivered'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      sender: json['senderId'] != null && json['senderId'] is Map
          ? User.fromJson(json['senderId'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'image': image,
      'seen': seen,
      'delivered': delivered,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isImage => image.isNotEmpty;
}
