import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';
import '../models/message.dart';

class SocketService {
  IO.Socket? _socket;
  Function(Message)? onMessageReceived;
  Function(String)? onUserTyping;
  Function(String)? onUserStopTyping;
  Function(String)? onMessagesSeen;
  Function(String)? onUserOnline;
  Function(String)? onUserOffline;

  void connect(String token) {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      Constants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Connected to socket');
    });

    _socket!.onDisconnect((_) {
      print('Disconnected from socket');
    });

    _socket!.on('receive-message', (data) {
      if (onMessageReceived != null) {
        onMessageReceived!(Message.fromJson(data));
      }
    });

    _socket!.on('user-typing', (data) {
      if (onUserTyping != null) {
        onUserTyping!(data['userId']);
      }
    });

    _socket!.on('user-stop-typing', (data) {
      if (onUserStopTyping != null) {
        onUserStopTyping!(data['userId']);
      }
    });

    _socket!.on('messages-seen', (data) {
      if (onMessagesSeen != null) {
        onMessagesSeen!(data['chatId']);
      }
    });

    _socket!.on('user-online', (data) {
      if (onUserOnline != null) {
        onUserOnline!(data['userId']);
      }
    });

    _socket!.on('user-offline', (data) {
      if (onUserOffline != null) {
        onUserOffline!(data['userId']);
      }
    });
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
