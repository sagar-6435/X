import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';
import '../utils/constants.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final String currentUserId;
  final String chatId;
  final void Function(String messageId, String deleteType) onDelete;
  final void Function(String messageId, String emoji) onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.currentUserId,
    required this.chatId,
    required this.onDelete,
    required this.onReact,
  });

  // Quick-pick emojis shown in the reaction bar
  static const _quickEmojis = ['❤️', '😂', '😮', '😢', '👍', '👎'];

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(Constants.surfaceColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reaction quick-pick row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _quickEmojis.map((emoji) {
                    final alreadyReacted = message.reactions.any(
                      (r) => r.userId == currentUserId && r.emoji == emoji,
                    );
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onReact(message.id, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: alreadyReacted
                              ? Color(Constants.primaryColor).withValues(alpha: 0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Delete for me
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white70),
                title: const Text('Delete for me',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete(message.id, 'me');
                },
              ),
              // Delete for everyone — only sender can do this
              if (isCurrentUser)
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('Delete for everyone',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete(message.id, 'everyone');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If deleted for everyone, show a tombstone bubble
    if (message.deletedForEveryone) {
      return _DeletedBubble(isCurrentUser: isCurrentUser);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showOptions(context),
            child: Row(
              mainAxisAlignment: isCurrentUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!isCurrentUser) ...[
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: message.isImage
                        ? const EdgeInsets.all(8)
                        : const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? Color(Constants.sentMessageColor)
                          : Color(Constants.receivedMessageColor),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isCurrentUser
                            ? const Radius.circular(20)
                            : const Radius.circular(4),
                        bottomRight: isCurrentUser
                            ? const Radius.circular(4)
                            : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: message.isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: message.image,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 200,
                                width: 200,
                                color: Color(Constants.cardColor),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(Constants.primaryColor),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 200,
                                width: 200,
                                color: Color(Constants.cardColor),
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Color(Constants.secondaryTextColor),
                                ),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(message.createdAt),
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      message.seen
                                          ? Icons.done_all
                                          : message.delivered
                                              ? Icons.done_all
                                              : Icons.done,
                                      size: 14,
                                      color: message.seen
                                          ? Colors.blue
                                          : Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                if (isCurrentUser) const SizedBox(width: 8),
              ],
            ),
          ),
          // Reactions row
          if (message.reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isCurrentUser ? 0 : 40,
                right: isCurrentUser ? 8 : 0,
              ),
              child: _ReactionsRow(
                reactions: message.reactions,
                currentUserId: currentUserId,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}:${(difference.inMinutes % 60).toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}

/// Tombstone shown when a message was deleted for everyone.
class _DeletedBubble extends StatelessWidget {
  final bool isCurrentUser;
  const _DeletedBubble({required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) const SizedBox(width: 40),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Text(
                  'This message was deleted',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Aggregated emoji reaction chips.
class _ReactionsRow extends StatelessWidget {
  final List<MessageReaction> reactions;
  final String currentUserId;

  const _ReactionsRow({
    required this.reactions,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // Aggregate: emoji → count
    final Map<String, int> counts = {};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }

    return Wrap(
      spacing: 4,
      children: counts.entries.map((entry) {
        final isMine = reactions.any(
          (r) => r.userId == currentUserId && r.emoji == entry.key,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isMine
                ? Color(Constants.primaryColor).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMine
                  ? Color(Constants.primaryColor).withValues(alpha: 0.6)
                  : Colors.white12,
            ),
          ),
          child: Text(
            entry.value > 1
                ? '${entry.key} ${entry.value}'
                : entry.key,
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
    );
  }
}
