import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();

  List<Chat> _chats = [];
  List<Message> _messages = [];
  List<User> _users = [];
  Map<String, bool> _typingUsers = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentChatId;

  List<Chat> get chats => _chats;
  List<Message> get messages => _messages;
  List<User> get users => _users;
  Map<String, bool> get typingUsers => _typingUsers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChatProvider() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // Incoming message from socket — reconcile with optimistic or add new
    _socketService.onMessageReceived = (message) {
      // Replace optimistic message (matched by sender + approximate time) with real one
      final optimisticIndex = _messages.indexWhere((m) =>
          m.senderId == message.senderId &&
          m.chatId == message.chatId &&
          m.text == message.text &&
          m.image == message.image &&
          message.createdAt.difference(m.createdAt).inSeconds.abs() < 10 &&
          !m.id.contains('-')); // real IDs from server don't contain '-'

      // Also check by real ID to avoid duplicates
      final existsById = _messages.any((m) => m.id == message.id);

      if (existsById) return; // already have it

      if (optimisticIndex >= 0) {
        _messages[optimisticIndex] = message; // replace optimistic with real
      } else {
        _messages.add(message);
      }
      _updateChatLastMessage(
          message.chatId, message.text.isNotEmpty ? message.text : '[Image]');
      notifyListeners();
    };

    // Recipient gets notified of new message even if not in the chat room
    _socketService.onNewMessageNotification = (chatId, message) {
      _updateChatLastMessage(
          chatId, message.text.isNotEmpty ? message.text : '[Image]');
      notifyListeners();
    };

    _socketService.onUserTyping = (userId) {
      _typingUsers[userId] = true;
      notifyListeners();
    };

    _socketService.onUserStopTyping = (userId) {
      _typingUsers.remove(userId);
      notifyListeners();
    };

    _socketService.onMessagesSeen = (chatId) {
      _messages = _messages
          .map((m) => Message(
                id: m.id,
                chatId: m.chatId,
                senderId: m.senderId,
                text: m.text,
                image: m.image,
                seen: true,
                createdAt: m.createdAt,
                sender: m.sender,
              ))
          .toList();
      notifyListeners();
    };

    _socketService.onUserStatus = (userId, online) {
      // Update online status in users list
      _users = _users
          .map((u) => u.id == userId
              ? User(
                  id: u.id,
                  name: u.name,
                  email: u.email,
                  profilePic: u.profilePic,
                  online: online,
                  lastSeen: u.lastSeen,
                )
              : u)
          .toList();
      notifyListeners();
    };
  }

  void _updateChatLastMessage(String chatId, String lastMessage) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index >= 0) {
      final chat = _chats[index];
      _chats[index] = Chat(
        id: chat.id,
        user: chat.user,
        lastMessage: lastMessage,
        updatedAt: DateTime.now(),
      );
      // Move to top
      final updated = _chats.removeAt(index);
      _chats.insert(0, updated);
    }
  }

  void connectSocket(String token, String userId) {
    _socketService.connect(token);
    // Register user as online globally
    Future.delayed(const Duration(milliseconds: 500), () {
      _socketService.setUserOnline(userId);
    });
  }

  void disconnectSocket() {
    _socketService.disconnect();
  }

  Future<void> loadChats(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.getChats(token);

      if (response['chats'] != null) {
        _chats = (response['chats'] as List)
            .map((chat) => Chat.fromJson(chat))
            .toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String token, String chatId) async {
    _isLoading = true;
    _errorMessage = null;
    _messages = [];
    _currentChatId = chatId;
    notifyListeners();

    try {
      final response = await ApiService.getMessages(token, chatId);

      if (response['messages'] != null) {
        _messages = (response['messages'] as List)
            .map((message) => Message.fromJson(message))
            .toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUsers(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.getAllUsers(token);

      if (response['users'] != null) {
        _users = (response['users'] as List)
            .map((user) => User.fromJson(user))
            .toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Chat?> getOrCreateChat(String token, String userId) async {
    try {
      final response = await ApiService.getOrCreateChat(token, userId);

      if (response['chat'] != null) {
        final chat = Chat.fromJson(response['chat']);

        final index = _chats.indexWhere((c) => c.id == chat.id);
        if (index >= 0) {
          _chats[index] = chat;
        } else {
          _chats.insert(0, chat);
        }

        notifyListeners();
        return chat;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return null;
  }

  void joinChat(String userId, String chatId) {
    _socketService.joinChat(userId, chatId);
  }

  void sendMessage({
    required String chatId,
    required String senderId,
    String text = '',
    String image = '',
  }) {
    // Optimistically add message locally so sender sees it immediately
    final optimisticMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      senderId: senderId,
      text: text,
      image: image,
      seen: false,
      createdAt: DateTime.now(),
    );
    _messages.add(optimisticMessage);
    _updateChatLastMessage(chatId, text.isNotEmpty ? text : '[Image]');
    notifyListeners();

    // Send via socket — server saves and broadcasts to others
    _socketService.sendMessage(
      chatId: chatId,
      senderId: senderId,
      text: text,
      image: image,
    );
  }

  void sendTyping(String chatId, String userId) {
    _socketService.typing(chatId, userId);
  }

  void stopTyping(String chatId, String userId) {
    _socketService.stopTyping(chatId, userId);
  }

  Future<void> markAsSeen(String token, String chatId, String userId) async {
    try {
      await ApiService.markMessagesAsSeen(token, chatId);
      _socketService.seenMessage(chatId, userId);
    } catch (e) {
      print('Error marking as seen: $e');
    }
  }

  Future<String?> uploadImage(String token, String imagePath) async {
    try {
      final response = await ApiService.uploadImage(token, imagePath);
      return response['imageUrl'];
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearMessages() {
    _messages = [];
    _currentChatId = null;
    notifyListeners();
  }
}
