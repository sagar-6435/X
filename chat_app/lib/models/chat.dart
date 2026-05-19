import 'user.dart';

class Chat {
  final String id;
  final User user;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;

  Chat({
    required this.id,
    required this.user,
    this.lastMessage = '',
    required this.updatedAt,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['_id'] ?? json['id'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
      lastMessage: json['lastMessage'] ?? '',
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'lastMessage': lastMessage,
      'updatedAt': updatedAt.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }
}
