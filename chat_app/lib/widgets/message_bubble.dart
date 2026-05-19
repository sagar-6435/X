import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';
import '../utils/constants.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isCurrentUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isCurrentUser && message.sender != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(Constants.primaryColor),
                  ),
                  child: message.sender!.profilePic.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: message.sender!.profilePic,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                message.sender!.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            message.sender!.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
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
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    message.seen
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
