import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/user.dart';
import '../utils/constants.dart';
import 'chat_room_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _isLoading = false;
  List<User> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.loadUsers(authProvider.token!);
      if (mounted) {
        setState(() {
          _users = chatProvider.users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _startChat(User user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final chat = await chatProvider.getOrCreateChat(
      authProvider.token!,
      user.id,
    );

    if (chat != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chat: chat,
            currentUserId: authProvider.user!.id,
          ),
        ),
      );
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
          'New Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(Constants.primaryColor),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 80,
                              color: Color(Constants.secondaryTextColor)),
                          const SizedBox(height: 16),
                          Text('No users found',
                              style: TextStyle(
                                  fontSize: 18,
                                  color:
                                      Color(Constants.secondaryTextColor))),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          return _buildUserTile(_users[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildUserTile(User user) {
    return GestureDetector(
      onTap: () => _startChat(user),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(Constants.cardColor).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(Constants.primaryColor),
              ),
              child: user.profilePic.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        user.profilePic,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(user.name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(user.name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
            ),
            const SizedBox(width: 16),
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
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user.online ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.online ? 'Online' : 'Offline',
                        style: TextStyle(
                            color: Color(Constants.secondaryTextColor),
                            fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(Constants.primaryColor).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_outlined,
                  color: Color(Constants.primaryColor)),
            ),
          ],
        ),
      ),
    );
  }
}
