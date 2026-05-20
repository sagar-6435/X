import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat.dart';
import '../models/user.dart';
import '../utils/constants.dart';
import 'chat_room_screen.dart';
import 'incoming_call_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _selectedTab = 0; // 0 = Chats, 1 = People

  @override
  void initState() {
    super.initState();
    _loadData();
    // Register incoming call handler so calls ring from anywhere in the app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.onIncomingCall =
          (callerId, chatId, callType, offer) {
        if (!mounted) return;
        // Find caller name from users list
        final callerUser = chatProvider.users.firstWhere(
          (u) => u.id == callerId,
          orElse: () => User(id: callerId, name: 'Unknown', email: ''),
        );
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => IncomingCallScreen(
            callerName: callerUser.name,
            callerProfilePic: callerUser.profilePic,
            callerId: callerId,
            calleeId:
                Provider.of<AuthProvider>(context, listen: false).user!.id,
            chatId: chatId,
            callType: callType,
            offer: offer,
          ),
        );
      };
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.token != null && authProvider.user != null) {
      chatProvider.connectSocket(authProvider.token!, authProvider.user!.id);
      await Future.wait([
        chatProvider.loadChats(authProvider.token!),
        chatProvider.loadUsers(authProvider.token!),
      ]);
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.disconnectSocket();
    await authProvider.logout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openChat(User user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final chat = await chatProvider.getOrCreateChat(
      authProvider.token!,
      user.id,
    );

    if (chat != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chat: chat,
            currentUserId: authProvider.user!.id,
          ),
        ),
      );
      // No need to reload — socket keeps chats list up to date in real-time
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(Constants.backgroundColor),
      appBar: AppBar(
        backgroundColor: Color(Constants.surfaceColor),
        elevation: 0,
        title: const Text(
          'X',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _tabButton('Chats', 0),
              _tabButton('People', 1),
            ],
          ),
        ),
      ),
      body: _selectedTab == 0 ? _buildChatsTab() : _buildPeopleTab(),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? Color(Constants.primaryColor)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Color(Constants.secondaryTextColor),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ── CHATS TAB ──────────────────────────────────────────────────────────────
  Widget _buildChatsTab() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        if (chatProvider.isLoading && chatProvider.chats.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(Constants.primaryColor)),
          );
        }

        if (chatProvider.chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 80, color: Color(Constants.secondaryTextColor)),
                const SizedBox(height: 16),
                Text('No chats yet',
                    style: TextStyle(
                        fontSize: 18, color: Color(Constants.secondaryTextColor))),
                const SizedBox(height: 8),
                Text('Go to People tab to start a conversation',
                    style: TextStyle(
                        fontSize: 14, color: Color(Constants.secondaryTextColor))),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            itemCount: chatProvider.chats.length,
            itemBuilder: (context, index) =>
                _buildChatTile(chatProvider.chats[index]),
          ),
        );
      },
    );
  }

  Widget _buildChatTile(Chat chat) {
    return Consumer2<AuthProvider, ChatProvider>(
      builder: (context, authProvider, chatProvider, _) {
        final unread = chatProvider.unreadCount(chat.id);
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(
                  chat: chat,
                  currentUserId: authProvider.user!.id,
                ),
              ),
            );
            // No need to reload — socket keeps chats list up to date in real-time
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(Constants.cardColor).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                _avatar(chat.user.name, chat.user.profilePic, chat.user.online),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(chat.user.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(_formatTime(chat.updatedAt),
                              style: TextStyle(
                                  color: Color(Constants.secondaryTextColor),
                                  fontSize: 11)),
                          if (unread > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.lastMessage.isEmpty ? 'Tap to chat' : chat.lastMessage,
                        style: TextStyle(
                            color: Color(Constants.secondaryTextColor),
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── PEOPLE TAB ─────────────────────────────────────────────────────────────
  Widget _buildPeopleTab() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        if (chatProvider.isLoadingUsers) {
          return const Center(
            child: CircularProgressIndicator(color: Color(Constants.primaryColor)),
          );
        }

        if (chatProvider.users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: 80, color: Color(Constants.secondaryTextColor)),
                const SizedBox(height: 16),
                Text('No users found',
                    style: TextStyle(
                        fontSize: 18,
                        color: Color(Constants.secondaryTextColor))),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            itemCount: chatProvider.users.length,
            itemBuilder: (context, index) =>
                _buildUserTile(chatProvider.users[index]),
          ),
        );
      },
    );
  }

  Widget _buildUserTile(User user) {
    return GestureDetector(
      onTap: () => _openChat(user),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color(Constants.cardColor).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            _avatar(user.name, user.profilePic, user.online),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user.online ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(user.online ? 'Online' : 'Offline',
                          style: TextStyle(
                              color: Color(Constants.secondaryTextColor),
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chat_outlined, color: Color(Constants.primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name, String profilePic, bool online) {
    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(Constants.primaryColor),
          ),
          child: profilePic.isNotEmpty
              ? ClipOval(
                  child: Image.network(profilePic,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                            child: Text(name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                          )),
                )
              : Center(
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
        ),
        if (online)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Color(Constants.backgroundColor), width: 2),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dateTime.day}/${dateTime.month}';
  }
}
