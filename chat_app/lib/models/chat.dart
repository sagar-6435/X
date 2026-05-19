import 'user.dart';

class Chat {
  final String id;
  final User user;
  final String lastMessage;
  final DateTime updatedAt;

  Chat({
    required this.id,
    required this.user,
    this.lastMessage = '',
    required this.updatedAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['_id'] ?? json['id'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
      lastMessage: json['lastMessage'] ?? '',
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'lastMessage': lastMessage,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
