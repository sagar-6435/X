import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/chat.dart';
import '../utils/constants.dart';
import '../widgets/message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  final Chat chat;
  final String currentUserId;

  const ChatRoomScreen({
    super.key,
    required this.chat,
    required this.currentUserId,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    await chatProvider.loadMessages(authProvider.token!, widget.chat.id);
    chatProvider.joinChat(widget.currentUserId, widget.chat.id);
    
    _scrollToBottom();
    
    // Mark messages as seen
    await chatProvider.markAsSeen(
      authProvider.token!,
      widget.chat.id,
      widget.currentUserId,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    chatProvider.sendMessage(
      chatId: widget.chat.id,
      senderId: widget.currentUserId,
      text: text,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    // image_picker removed — re-add when network is available
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image sharing coming soon')),
    );
  }

  void _onTyping(bool isTyping) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (isTyping && !_isTyping) {
      chatProvider.sendTyping(widget.chat.id, widget.currentUserId);
      _isTyping = true;
    } else if (!isTyping && _isTyping) {
      chatProvider.stopTyping(widget.chat.id, widget.currentUserId);
      _isTyping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(Constants.backgroundColor),
      appBar: AppBar(
        backgroundColor: Color(Constants.surfaceColor),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(Constants.primaryColor),
              ),
              child: widget.chat.user.profilePic.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        widget.chat.user.profilePic,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              widget.chat.user.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        widget.chat.user.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      final isTyping = chatProvider.typingUsers.containsKey(
                        widget.chat.user.id,
                      );
                      return Text(
                        isTyping
                            ? 'typing...'
                            : widget.chat.user.online
                                ? 'Online'
                                : 'Offline',
                        style: TextStyle(
                          color: isTyping
                              ? Color(Constants.primaryColor)
                              : Color(Constants.secondaryTextColor),
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(Constants.primaryColor),
                    ),
                  );
                }

                if (chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Color(Constants.secondaryTextColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(Constants.secondaryTextColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(Constants.secondaryTextColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatProvider.messages[index];
                    return MessageBubble(
                      message: message,
                      isCurrentUser: message.senderId == widget.currentUserId,
                    );
                  },
                );
              },
            ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(Constants.surfaceColor),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.image_outlined,
                    color: Color(Constants.primaryColor),
                  ),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(Constants.cardColor).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Color(Constants.secondaryTextColor),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        _onTyping(value.isNotEmpty);
                      },
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(Constants.primaryColor),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
