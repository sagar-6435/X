import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/chat.dart';
import '../utils/constants.dart';
import '../utils/permission_service.dart';
import '../widgets/message_bubble.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _showScrollToBottom = false;
  int _lastMessageCount = 0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.addListener(_onMessagesChanged);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (_isTyping) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.stopTyping(widget.chat.id, widget.currentUserId);
    }
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.removeListener(_onMessagesChanged);
    super.dispose();
  }

  void _onMessagesChanged() {
    if (!mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final newCount = chatProvider.messages.length;
    if (newCount > _lastMessageCount) {
      _lastMessageCount = newCount;
      if (_scrollController.hasClients) {
        final distanceFromBottom = _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels;
        if (distanceFromBottom < 150) _scrollToBottom();
      }
    } else {
      _lastMessageCount = newCount;
    }
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
        if (_showScrollToBottom) setState(() => _showScrollToBottom = false);
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
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

  // ── Attachment picker ────────────────────────────────────────────────────────

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(Constants.surfaceColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              _AttachOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              _AttachOption(
                icon: Icons.insert_drive_file_rounded,
                label: 'Document',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // Camera needs camera permission; gallery needs photos permission.
    final granted = source == ImageSource.camera
        ? await PermissionService.requestCameraAndMicrophone(context)
        : await PermissionService.requestPhotos(context);
    if (!granted || !mounted) return;

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (file == null || !mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      setState(() => _isUploading = true);
      final imageUrl =
          await chatProvider.uploadImage(authProvider.token!, file.path);
      setState(() => _isUploading = false);

      if (imageUrl != null && mounted) {
        chatProvider.sendMessage(
          chatId: widget.chat.id,
          senderId: widget.currentUserId,
          image: imageUrl,
        );
        _scrollToBottom();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    final granted = await PermissionService.requestStorage(context);
    if (!granted || !mounted) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.first;
      if (file.path == null) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      setState(() => _isUploading = true);
      final data = await chatProvider.uploadDocument(
        authProvider.token!,
        file.path!,
        file.name,
      );
      setState(() => _isUploading = false);

      if (data != null && mounted) {
        chatProvider.sendMessage(
          chatId: widget.chat.id,
          senderId: widget.currentUserId,
          fileUrl: data['fileUrl'] ?? '',
          fileName: data['originalName'] ?? file.name,
          fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
          fileExt: data['ext'] ?? '',
        );
        _scrollToBottom();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload document')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ── Calls ────────────────────────────────────────────────────────────────────

  void _startVoiceCall() async {
    final granted = await PermissionService.requestMicrophone(context);
    if (!granted || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          userName: widget.chat.user.name,
          userInitial: widget.chat.user.name[0],
          profilePic: widget.chat.user.profilePic,
          calleeId: widget.chat.user.id,
          callerId: widget.currentUserId,
          chatId: widget.chat.id,
          isCaller: true,
        ),
      ),
    );
  }

  void _startVideoCall() async {
    final granted = await PermissionService.requestCameraAndMicrophone(context);
    if (!granted || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          userName: widget.chat.user.name,
          userProfilePic: widget.chat.user.profilePic.isNotEmpty
              ? widget.chat.user.profilePic
              : null,
          calleeId: widget.chat.user.id,
          callerId: widget.currentUserId,
          chatId: widget.chat.id,
          isCaller: true,
        ),
      ),
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
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear',
                style: TextStyle(color: Colors.redAccent)),
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Chat cleared')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to clear chat: $e')));
        }
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
              width: 42,
              height: 42,
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
                      final liveUser = chatProvider.users.firstWhere(
                        (u) => u.id == widget.chat.user.id,
                        orElse: () => widget.chat.user,
                      );
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isTyping
                              ? 'typing...'
                              : liveUser.online
                                  ? 'Online'
                                  : 'Offline',
                          key: ValueKey('$isTyping-${liveUser.online}'),
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
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            onPressed: _startVideoCall,
            tooltip: 'Video call',
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Colors.white),
            onPressed: _startVoiceCall,
            tooltip: 'Voice call',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Color(Constants.surfaceColor),
            onSelected: (value) {
              if (value == 'clear') _showClearChatDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Clear chat',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload progress bar
          if (_isUploading)
            LinearProgressIndicator(
              backgroundColor: Color(Constants.surfaceColor),
              color: Color(Constants.primaryColor),
              minHeight: 3,
            ),

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

                if (chatProvider.messages.isEmpty && !isOtherTyping) {
                  return _emptyState();
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: chatProvider.messages.length +
                          (isOtherTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isOtherTyping &&
                            index == chatProvider.messages.length) {
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
                                  color:
                                      Colors.white.withValues(alpha: 0.15)),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            decoration: BoxDecoration(
              color: Color(Constants.surfaceColor),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button
                IconButton(
                  icon: Icon(Icons.attach_file_rounded,
                      color: Color(Constants.secondaryTextColor)),
                  onPressed: _showAttachmentSheet,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                // Text field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color:
                          Color(Constants.cardColor).withValues(alpha: 0.5),
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
                            horizontal: 18, vertical: 10),
                      ),
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(Constants.primaryColor),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
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
                  fontSize: 18,
                  color: Color(Constants.secondaryTextColor))),
          const SizedBox(height: 8),
          Text('Start the conversation',
              style: TextStyle(
                  fontSize: 14,
                  color: Color(Constants.secondaryTextColor))),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

// ── Attachment option chip ────────────────────────────────────────────────────

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Typing dots ───────────────────────────────────────────────────────────────

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
            final progress = (_controller.value + i * 0.33) % 1.0;
            final opacity =
                progress < 0.5 ? progress * 2 : (1.0 - progress) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
