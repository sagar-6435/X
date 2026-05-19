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
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    await chatProvider.loadUsers(authProvider.token!);
  }

  Future<void> _startChat(User user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    final chat = await chatProvider.getOrCreateChat(
      authProvider.token!,
      user.id,
    );

    if (chat != null && mounted) {
      Navigator.push(
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(Constants.primaryColor),
              ),
            );
          }

          if (chatProvider.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Color(Constants.secondaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(Constants.secondaryTextColor),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chatProvider.users.length,
            itemBuilder: (context, index) {
              final user = chatProvider.users[index];
              return _buildUserTile(user);
            },
          );
        },
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
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Profile picture
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
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              user.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        user.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (user.online)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                      if (user.online) const SizedBox(width: 8),
                      Text(
                        user.online ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: Color(Constants.secondaryTextColor),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Chat icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(Constants.primaryColor).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_outlined,
                color: Color(Constants.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
