class User {
  final String id;
  final String name;
  final String email;
  final String profilePic;
  final bool online;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePic = '',
    this.online = false,
    this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profilePic: json['profilePic'] ?? '',
      online: json['online'] ?? false,
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profilePic': profilePic,
      'online': online,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}
