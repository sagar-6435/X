import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';
import '../models/message.dart';

class SocketService {
  IO.Socket? _socket;

  // Chat callbacks
  Function(Message)? onMessageReceived;
  Function(String)? onUserTyping;
  Function(String)? onUserStopTyping;
  Function(String)? onMessagesSeen;
  Function(String, bool)? onUserStatus;
  Function(String, Message)? onNewMessageNotification;
  Function(String)? onMessageDelivered;
  Function(String, String, String)? onMessageDeleted;
  Function(String, List<MessageReaction>, String)? onMessageReacted;

  // WebRTC call callbacks
  Function(String callerId, String chatId, String callType, dynamic offer)? onIncomingCall;
  Function(dynamic answer)? onCallAnswered;
  Function(dynamic candidate)? onIceCandidate;
  Function()? onCallDeclined;
  Function()? onCallEnded;
  Function(String reason)? onCallFailed;

  void connect(String token) {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      Constants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) => print('Socket connected'));
    _socket!.onDisconnect((_) => print('Socket disconnected'));
    _socket!.onReconnect((_) => print('Socket reconnected'));

    // ── Chat events ──────────────────────────────────────────────────────────

    _socket!.on('receive-message', (data) {
      onMessageReceived?.call(Message.fromJson(data));
    });

    _socket!.on('user-typing', (data) {
      onUserTyping?.call(data['userId']);
    });

    _socket!.on('user-stop-typing', (data) {
      onUserStopTyping?.call(data['userId']);
    });

    _socket!.on('messages-seen', (data) {
      onMessagesSeen?.call(data['chatId']);
    });

    _socket!.on('user-status', (data) {
      onUserStatus?.call(data['userId'], data['online'] == true);
    });

    _socket!.on('new-message-notification', (data) {
      onNewMessageNotification?.call(
        data['chatId'],
        Message.fromJson(data['message']),
      );
    });

    _socket!.on('message-delivered', (data) {
      onMessageDelivered?.call(data['messageId']);
    });

    _socket!.on('message-deleted', (data) {
      onMessageDeleted?.call(data['messageId'], data['deleteType'], data['chatId']);
    });

    _socket!.on('message-reacted', (data) {
      final reactions = (data['reactions'] as List)
          .map((r) => MessageReaction.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      onMessageReacted?.call(data['messageId'], reactions, data['chatId']);
    });

    // ── WebRTC call events ───────────────────────────────────────────────────

    _socket!.on('incoming-call', (data) {
      onIncomingCall?.call(
        data['callerId'],
        data['chatId'],
        data['callType'],
        data['offer'],
      );
    });

    _socket!.on('call-answered', (data) {
      onCallAnswered?.call(data['answer']);
    });

    _socket!.on('ice-candidate', (data) {
      onIceCandidate?.call(data['candidate']);
    });

    _socket!.on('call-declined', (_) {
      onCallDeclined?.call();
    });

    _socket!.on('call-ended', (_) {
      onCallEnded?.call();
    });

    _socket!.on('call-failed', (data) {
      onCallFailed?.call(data['reason'] ?? 'Call failed');
    });
  }

  // ── Chat emitters ────────────────────────────────────────────────────────

  void setUserOnline(String userId) {
    _socket?.emit('user-online', {'userId': userId});
  }

  void joinChat(String userId, String chatId) {
    _socket?.emit('join-chat', {'userId': userId, 'chatId': chatId});
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
    _socket?.emit('send-message', {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'image': image,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileExt': fileExt,
    });
  }

  void deleteMessage({
    required String messageId,
    required String deleteType,
    required String userId,
    required String chatId,
  }) {
    _socket?.emit('delete-message', {
      'messageId': messageId,
      'deleteType': deleteType,
      'userId': userId,
      'chatId': chatId,
    });
  }

  void reactMessage({
    required String messageId,
    required String userId,
    required String emoji,
    required String chatId,
  }) {
    _socket?.emit('react-message', {
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
      'chatId': chatId,
    });
  }

  void typing(String chatId, String userId) {
    _socket?.emit('typing', {'chatId': chatId, 'userId': userId});
  }

  void stopTyping(String chatId, String userId) {
    _socket?.emit('stop-typing', {'chatId': chatId, 'userId': userId});
  }

  void seenMessage(String chatId, String userId) {
    _socket?.emit('seen-message', {'chatId': chatId, 'userId': userId});
  }

  // ── WebRTC call emitters ─────────────────────────────────────────────────

  void callUser({
    required String callerId,
    required String calleeId,
    required String chatId,
    required String callType,
    required dynamic offer,
  }) {
    _socket?.emit('call-user', {
      'callerId': callerId,
      'calleeId': calleeId,
      'chatId': chatId,
      'callType': callType,
      'offer': offer,
    });
  }

  void answerCall({
    required String callerId,
    required String calleeId,
    required dynamic answer,
  }) {
    _socket?.emit('call-answer', {
      'callerId': callerId,
      'calleeId': calleeId,
      'answer': answer,
    });
  }

  void sendIceCandidate({
    required String targetUserId,
    required dynamic candidate,
  }) {
    _socket?.emit('ice-candidate', {
      'targetUserId': targetUserId,
      'candidate': candidate,
    });
  }

  void declineCall({
    required String callerId,
    required String calleeId,
    required String chatId,
    required String callType,
  }) {
    _socket?.emit('call-declined', {
      'callerId': callerId,
      'calleeId': calleeId,
      'chatId': chatId,
      'callType': callType,
    });
  }

  void endCall({
    required String targetUserId,
    required String chatId,
    required String callType,
    required String senderId,
    int callDuration = 0,
  }) {
    _socket?.emit('call-ended', {
      'targetUserId': targetUserId,
      'chatId': chatId,
      'callType': callType,
      'senderId': senderId,
      'callDuration': callDuration,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  bool get isConnected => _socket != null && _socket!.connected;
}
