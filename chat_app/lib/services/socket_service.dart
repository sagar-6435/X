import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';
import '../models/message.dart';

class SocketService {
  IO.Socket? _socket;
  Function(Message)? onMessageReceived;
  Function(String)? onUserTyping;
  Function(String)? onUserStopTyping;
  Function(String)? onMessagesSeen;
  Function(String, bool)? onUserStatus;
  Function(String, Message)? onNewMessageNotification;
  Function(String)? onMessageDelivered;
  // messageId, deleteType ('me' | 'everyone'), chatId
  Function(String, String, String)? onMessageDeleted;
  // messageId, reactions list, chatId
  Function(String, List<MessageReaction>, String)? onMessageReacted;

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

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onReconnect((_) {
      print('Socket reconnected');
    });

    _socket!.on('receive-message', (data) {
      if (onMessageReceived != null) {
        onMessageReceived!(Message.fromJson(data));
      }
    });

    _socket!.on('user-typing', (data) {
      if (onUserTyping != null) onUserTyping!(data['userId']);
    });

    _socket!.on('user-stop-typing', (data) {
      if (onUserStopTyping != null) onUserStopTyping!(data['userId']);
    });

    _socket!.on('messages-seen', (data) {
      if (onMessagesSeen != null) onMessagesSeen!(data['chatId']);
    });

    _socket!.on('user-status', (data) {
      if (onUserStatus != null) {
        onUserStatus!(data['userId'], data['online'] == true);
      }
    });

    _socket!.on('new-message-notification', (data) {
      if (onNewMessageNotification != null) {
        onNewMessageNotification!(
          data['chatId'],
          Message.fromJson(data['message']),
        );
      }
    });

    _socket!.on('message-delivered', (data) {
      if (onMessageDelivered != null) {
        onMessageDelivered!(data['messageId']);
      }
    });

    _socket!.on('message-deleted', (data) {
      if (onMessageDeleted != null) {
        onMessageDeleted!(
          data['messageId'],
          data['deleteType'],
          data['chatId'],
        );
      }
    });

    _socket!.on('message-reacted', (data) {
      if (onMessageReacted != null) {
        final reactions = (data['reactions'] as List)
            .map((r) => MessageReaction.fromJson(Map<String, dynamic>.from(r)))
            .toList();
        onMessageReacted!(data['messageId'], reactions, data['chatId']);
      }
    });
  }

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
  }) {
    _socket?.emit('send-message', {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'image': image,
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

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  bool get isConnected => _socket != null && _socket!.connected;
}
