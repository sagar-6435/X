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
  Map<String, int> _unreadCounts = {};
  bool _isLoadingChats = false;
  bool _isLoadingUsers = false;
  bool _isLoadingMessages = false;
  String? _errorMessage;
  String? _activeChatId;

  // WebRTC call callbacks — set by call screens
  Function(dynamic answer)? onCallAnswered;
  Function(dynamic candidate)? onIceCandidate;
  Function()? onCallDeclined;
  Function()? onCallEnded;

  // Incoming call callback — set by the root navigator widget
  Function(String callerId, String chatId, String callType, dynamic offer)?
      onIncomingCall;

  List<Chat> get chats => _chats;
  List<Message> get messages => _messages;
  List<User> get users => _users;
  Map<String, bool> get typingUsers => _typingUsers;
  bool get isLoading => _isLoadingChats || _isLoadingMessages;
  bool get isLoadingUsers => _isLoadingUsers;
  String? get errorMessage => _errorMessage;
  String? get activeChatId => _activeChatId;

  int unreadCount(String chatId) => _unreadCounts[chatId] ?? 0;

  ChatProvider() {
    _setupSocketListeners();
  }

  // ── Socket listeners ────────────────────────────────────────────────────────

  void _setupSocketListeners() {
    _socketService.onMessageReceived = (message) {
      final existsById = _messages.any((m) => m.id == message.id);
      if (existsById) return;

      final optimisticIndex = _messages.indexWhere((m) =>
          m.senderId == message.senderId &&
          m.chatId == message.chatId &&
          m.text == message.text &&
          m.image == message.image &&
          m.fileUrl == message.fileUrl &&
          message.createdAt.difference(m.createdAt).inSeconds.abs() < 10 &&
          RegExp(r'^\d+$').hasMatch(m.id));

      if (optimisticIndex >= 0) {
        _messages[optimisticIndex] = message;
      } else {
        _messages.add(message);
      }
      _updateChatLastMessage(message.chatId, _lastMsgPreview(message));
      notifyListeners();
    };

    _socketService.onNewMessageNotification = (chatId, message) {
      _updateChatLastMessage(chatId, _lastMsgPreview(message));
      _unreadCounts[chatId] = (_unreadCounts[chatId] ?? 0) + 1;
      notifyListeners();
    };

    _socketService.onMessageDelivered = (messageId) {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(delivered: true);
        notifyListeners();
      }
    };

    _socketService.onMessageDeleted = (messageId, deleteType, chatId) {
      if (deleteType == 'everyone') {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          _messages[index] = _messages[index].copyWith(
            deletedForEveryone: true,
            text: '',
            image: '',
            fileUrl: '',
          );
          notifyListeners();
        }
      }
    };

    _socketService.onMessageReacted = (messageId, reactions, chatId) {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(reactions: reactions);
        notifyListeners();
      }
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
      _messages = _messages.map((m) => m.copyWith(seen: true)).toList();
      notifyListeners();
    };

    _socketService.onUserStatus = (userId, online) {
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
      _chats = _chats
          .map((c) => c.user.id == userId
              ? Chat(
                  id: c.id,
                  user: User(
                    id: c.user.id,
                    name: c.user.name,
                    email: c.user.email,
                    profilePic: c.user.profilePic,
                    online: online,
                    lastSeen: c.user.lastSeen,
                  ),
                  lastMessage: c.lastMessage,
                  updatedAt: c.updatedAt,
                  unreadCount: c.unreadCount,
                )
              : c)
          .toList();
      notifyListeners();
    };

    // WebRTC signaling — forward to whichever call screen is active
    _socketService.onIncomingCall =
        (callerId, chatId, callType, offer) {
      onIncomingCall?.call(callerId, chatId, callType, offer);
    };

    _socketService.onCallAnswered = (answer) {
      onCallAnswered?.call(answer);
    };

    _socketService.onIceCandidate = (candidate) {
      onIceCandidate?.call(candidate);
    };

    _socketService.onCallDeclined = () {
      onCallDeclined?.call();
    };

    _socketService.onCallEnded = () {
      onCallEnded?.call();
    };

    _socketService.onCallFailed = (reason) {
      // surfaced via onCallDeclined for simplicity
      onCallDeclined?.call();
    };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _lastMsgPreview(Message m) {
    if (m.text.isNotEmpty) return m.text;
    if (m.image.isNotEmpty) return '📷 Image';
    if (m.fileUrl.isNotEmpty) return '📎 ${m.fileName.isNotEmpty ? m.fileName : "File"}';
    if (m.callType == 'voice_call') return '📞 Voice call';
    if (m.callType == 'video_call') return '🎥 Video call';
    return '';
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
        unreadCount: chat.unreadCount,
      );
      final updated = _chats.removeAt(index);
      _chats.insert(0, updated);
    }
  }

  // ── Connection ───────────────────────────────────────────────────────────────

  void connectSocket(String token, String userId) {
    _socketService.connect(token);
    Future.delayed(const Duration(milliseconds: 500), () {
      _socketService.setUserOnline(userId);
    });
  }

  void disconnectSocket() {
    _socketService.disconnect();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> loadChats(String token) async {
    _isLoadingChats = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await ApiService.getChats(token);
      if (response['chats'] != null) {
        _chats = (response['chats'] as List)
            .map((chat) => Chat.fromJson(chat))
            .toList();
        for (final chat in _chats) {
          _unreadCounts[chat.id] = chat.unreadCount;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingChats = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String token, String chatId) async {
    if (_activeChatId != chatId) {
      _messages = [];
      _activeChatId = chatId;
    }
    final firstLoad = _messages.isEmpty;
    if (firstLoad) {
      _isLoadingMessages = true;
      notifyListeners();
    }
    _errorMessage = null;
    try {
      final response = await ApiService.getMessages(token, chatId);
      if (response['messages'] != null) {
        _messages = (response['messages'] as List)
            .map((message) => Message.fromJson(message))
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> loadUsers(String token) async {
    _isLoadingUsers = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await ApiService.getAllUsers(token);
      if (response['users'] != null) {
        _users = (response['users'] as List)
            .map((user) => User.fromJson(user))
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingUsers = false;
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

  // ── Messaging ────────────────────────────────────────────────────────────────

  void joinChat(String userId, String chatId) {
    _socketService.joinChat(userId, chatId);
  }

  void sendMessage({
    required String chatId,
    required String senderId,
    String text = '',
    String image = '',
    String fileUrl = '',
    String fileName = '',
    int fileSize = 0,
    String fileExt = '',
  }) {
    final optimisticMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      senderId: senderId,
      text: text,
      image: image,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileExt: fileExt,
      seen: false,
      createdAt: DateTime.now(),
    );
    _messages.add(optimisticMessage);
    _updateChatLastMessage(chatId, _lastMsgPreview(optimisticMessage));
    notifyListeners();

    _socketService.sendMessage(
      chatId: chatId,
      senderId: senderId,
      text: text,
      image: image,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileExt: fileExt,
    );
  }

  void sendTyping(String chatId, String userId) =>
      _socketService.typing(chatId, userId);

  void stopTyping(String chatId, String userId) =>
      _socketService.stopTyping(chatId, userId);

  Future<void> markAsSeen(String token, String chatId, String userId) async {
    try {
      await ApiService.markMessagesAsSeen(token, chatId);
      _socketService.seenMessage(chatId, userId);
      _unreadCounts[chatId] = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking as seen: $e');
    }
  }

  // ── Uploads ──────────────────────────────────────────────────────────────────

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

  Future<Map<String, dynamic>?> uploadDocument(
      String token, String filePath, String fileName) async {
    try {
      final response =
          await ApiService.uploadDocument(token, filePath, fileName);
      if (response['fileUrl'] != null) return response;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return null;
  }

  // ── Chat management ──────────────────────────────────────────────────────────

  Future<void> clearChat(String token, String chatId) async {
    try {
      await ApiService.clearChat(token, chatId);
      _messages = [];
      _unreadCounts[chatId] = 0;
      final index = _chats.indexWhere((c) => c.id == chatId);
      if (index >= 0) {
        final chat = _chats[index];
        _chats[index] = Chat(
          id: chat.id,
          user: chat.user,
          lastMessage: '',
          updatedAt: DateTime.now(),
          unreadCount: 0,
        );
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearMessages() {
    _messages = [];
    _activeChatId = null;
    notifyListeners();
  }

  void deleteMessage({
    required String messageId,
    required String deleteType,
    required String currentUserId,
    required String chatId,
  }) {
    if (deleteType == 'me') {
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } else {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(
          deletedForEveryone: true,
          text: '',
          image: '',
          fileUrl: '',
        );
        notifyListeners();
      }
    }
    _socketService.deleteMessage(
      messageId: messageId,
      deleteType: deleteType,
      userId: currentUserId,
      chatId: chatId,
    );
  }

  void reactToMessage({
    required String messageId,
    required String currentUserId,
    required String emoji,
    required String chatId,
  }) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final existing = List<MessageReaction>.from(_messages[index].reactions);
      final userIndex =
          existing.indexWhere((r) => r.userId == currentUserId);
      if (userIndex >= 0) {
        if (existing[userIndex].emoji == emoji) {
          existing.removeAt(userIndex);
        } else {
          existing[userIndex] =
              MessageReaction(userId: currentUserId, emoji: emoji);
        }
      } else {
        existing.add(MessageReaction(userId: currentUserId, emoji: emoji));
      }
      _messages[index] = _messages[index].copyWith(reactions: existing);
      notifyListeners();
    }
    _socketService.reactMessage(
      messageId: messageId,
      userId: currentUserId,
      emoji: emoji,
      chatId: chatId,
    );
  }

  // ── WebRTC call actions ──────────────────────────────────────────────────────

  void initiateCall({
    required String calleeId,
    required String chatId,
    required String callType,
    required dynamic offer,
  }) {
    // callerId is resolved server-side from the socket auth token,
    // but we still pass it for the callee's incoming-call event.
    // The provider doesn't store currentUserId, so the screen passes it via
    // the socket directly.
    _socketService.callUser(
      callerId: '', // filled by socket service from auth
      calleeId: calleeId,
      chatId: chatId,
      callType: callType,
      offer: offer,
    );
  }

  void answerCall({required String callerId, required dynamic answer}) {
    _socketService.answerCall(
      callerId: callerId,
      calleeId: '', // server resolves from socket
      answer: answer,
    );
  }

  void sendIceCandidate(
      {required String targetUserId, required dynamic candidate}) {
    _socketService.sendIceCandidate(
        targetUserId: targetUserId, candidate: candidate);
  }

  void declineCall({
    required String callerId,
    required String calleeId,
    required String chatId,
    required String callType,
  }) {
    _socketService.declineCall(
      callerId: callerId,
      calleeId: calleeId,
      chatId: chatId,
      callType: callType,
    );
  }

  void endCall({
    required String targetUserId,
    required String chatId,
    required String callType,
    required int callDuration,
  }) {
    _socketService.endCall(
      targetUserId: targetUserId,
      chatId: chatId,
      callType: callType,
      senderId: '',
      callDuration: callDuration,
    );
  }
}
