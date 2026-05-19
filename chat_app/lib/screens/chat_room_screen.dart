import 'dart:async';
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
  Timer? _typingTimer;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Stop typing on exit
    if (_isTyping) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.stopTyping(widget.chat.id, widget.currentUserId);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final distanceFromBottom = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final shouldShow = distanceFromBottom > 120;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  Future<void> _loadMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    chatProvider.joinChat(widget.currentUserId, widget.chat.id);
    await chatProvider.loadMessages(authProvider.token!, widget.chat.id);
    _scrollToBottom();

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
        if (_showScrollToBottom) {
          setState(() => _showScrollToBottom = false);
        }
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // Stop typing indicator before sending
    _typingTimer?.cancel();
    if (_isTyping) {
      chatProvider.stopTyping(widget.chat.id, widget.currentUserId);
      _isTyping = false;
    }

    chatProvider.sendMessage(
      chatId: widget.chat.id,
      senderId: widget.currentUserId,
      text: text,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _onTextChanged(String value) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (value.isNotEmpty) {
      if (!_isTyping) {
        chatProvider.sendTyping(widget.chat.id, widget.currentUserId);
        _isTyping = true;
      }
      // Reset auto-stop timer on every keystroke
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTyping) {
          chatProvider.stopTyping(widget.chat.id, widget.currentUserId);
          _isTyping = false;
        }
      });
    } else {
      _typingTimer?.cancel();
      if (_isTyping) {
        chatProvider.stopTyping(widget.chat.id, widget.currentUserId);
        _isTyping = false;
      }
    }
  }

  Future<void> _pickImage() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image sharing coming soon')),
    );
  }

  Future<void> _showClearChatDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(Constants.surfaceColor),
        title: const Text('Clear chat', style: TextStyle(color: Colors.white)),
        content: const Text(
          'All messages in this chat will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      try {
        await chatProvider.clearChat(authProvider.token!, widget.chat.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear chat: $e')),
          );
        }
      }
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
            // Avatar
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
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            widget.chat.user.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        widget.chat.user.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
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
                        fontSize: 16),
                  ),
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, _) {
                      final isTyping = chatProvider.typingUsers
                          .containsKey(widget.chat.user.id);
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isTyping
                              ? 'typing...'
                              : widget.chat.user.online
                                  ? 'Online'
                                  : 'Offline',
                          key: ValueKey(isTyping),
                          style: TextStyle(
                            color: isTyping
                                ? Color(Constants.primaryColor)
                                : Color(Constants.secondaryTextColor),
                            fontSize: 12,
                            fontStyle: isTyping
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Color(Constants.surfaceColor),
            onSelected: (value) async {
              if (value == 'clear') {
                _showClearChatDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Clear chat', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                if (chatProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(Constants.primaryColor)),
                  );
                }

                final isOtherTyping = chatProvider.typingUsers
                    .containsKey(widget.chat.user.id);

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      // +1 for typing bubble when other user is typing
                      itemCount: chatProvider.messages.isEmpty && !isOtherTyping
                          ? 0
                          : chatProvider.messages.length + (isOtherTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Empty state
                        if (chatProvider.messages.isEmpty && !isOtherTyping) {
                          return _emptyState();
                        }

                        // Typing bubble at the end
                        if (isOtherTyping &&
                            index == chatProvider.messages.length) {
                          WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _scrollToBottom());
                          return _typingBubble();
                        }

                        final message = chatProvider.messages[index];
                        return MessageBubble(
                          message: message,
                          isCurrentUser:
                              message.senderId == widget.currentUserId,
                          currentUserId: widget.currentUserId,
                          chatId: widget.chat.id,
                          onDelete: (messageId, deleteType) {
                            chatProvider.deleteMessage(
                              messageId: messageId,
                              deleteType: deleteType,
                              currentUserId: widget.currentUserId,
                              chatId: widget.chat.id,
                            );
                          },
                          onReact: (messageId, emoji) {
                            chatProvider.reactToMessage(
                              messageId: messageId,
                              currentUserId: widget.currentUserId,
                              emoji: emoji,
                              chatId: widget.chat.id,
                            );
                          },
                        );
                      },
                    ),
                    // Scroll-to-bottom arrow
                    if (_showScrollToBottom)
                      Positioned(
                        bottom: 12,
                        right: 16,
                        child: GestureDetector(
                          onTap: _scrollToBottom,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(Constants.surfaceColor),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Show empty state outside list when no messages
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              if (!chatProvider.isLoading &&
                  chatProvider.messages.isEmpty &&
                  !chatProvider.typingUsers.containsKey(widget.chat.user.id)) {
                return Expanded(child: _emptyState());
              }
              return const SizedBox.shrink();
            },
          ),

          // Input field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(Constants.surfaceColor),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image_outlined,
                      color: Color(Constants.primaryColor)),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(Constants.cardColor).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                            color: Color(Constants.secondaryTextColor)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onChanged: _onTextChanged,
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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 80, color: Color(Constants.secondaryTextColor)),
          const SizedBox(height: 16),
          Text('No messages yet',
              style: TextStyle(
                  fontSize: 18, color: Color(Constants.secondaryTextColor))),
          const SizedBox(height: 8),
          Text('Start the conversation',
              style: TextStyle(
                  fontSize: 14, color: Color(Constants.secondaryTextColor))),
        ],
      ),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(Constants.receivedMessageColor),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: _TypingDots(),
          ),
        ],
      ),
    );
  }
}

/// Animated three-dot typing indicator
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot animates with a 300ms offset
            final progress = (_controller.value + i * 0.33) % 1.0;
            final opacity = progress < 0.5
                ? progress * 2
                : (1.0 - progress) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
