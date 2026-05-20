import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
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

  static const _quickEmojis = ['❤️', '😂', '😮', '😢', '👍', '👎'];

  void _showOptions(BuildContext context) {
    // Call messages don't get reactions or delete options
    if (message.isCall) return;

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
              // Reaction row
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
                              ? Color(Constants.primaryColor)
                                  .withValues(alpha: 0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white70),
                title: const Text('Delete for me',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete(message.id, 'me');
                },
              ),
              if (isCurrentUser)
                ListTile(
                  leading: const Icon(Icons.delete_forever,
                      color: Colors.redAccent),
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
    if (message.deletedForEveryone) {
      return _DeletedBubble(isCurrentUser: isCurrentUser);
    }

    // Call log — centered, no bubble
    if (message.isCall) {
      return _CallLogTile(message: message, isCurrentUser: isCurrentUser);
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
                if (!isCurrentUser) const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: _bubblePadding,
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
                    child: _buildContent(context),
                  ),
                ),
                if (isCurrentUser) const SizedBox(width: 8),
              ],
            ),
          ),
          // Reactions
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

  EdgeInsets get _bubblePadding {
    if (message.isImage) return const EdgeInsets.all(6);
    if (message.isDocument) return const EdgeInsets.all(12);
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  Widget _buildContent(BuildContext context) {
    if (message.isImage) return _ImageContent(imageUrl: message.image);
    if (message.isDocument) {
      return _DocumentContent(
        fileName: message.fileName,
        fileSize: message.fileSize,
        fileExt: message.fileExt,
        fileUrl: message.fileUrl,
        isCurrentUser: isCurrentUser,
        createdAt: message.createdAt,
      );
    }
    return _TextContent(
      text: message.text,
      isCurrentUser: isCurrentUser,
      seen: message.seen,
      delivered: message.delivered,
      createdAt: message.createdAt,
    );
  }

}

// ── Image content ─────────────────────────────────────────────────────────────

class _ImageContent extends StatelessWidget {
  final String imageUrl;
  const _ImageContent({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: 220,
        placeholder: (_, __) => Container(
          height: 180,
          width: 220,
          color: Color(Constants.cardColor),
          child: const Center(
            child: CircularProgressIndicator(
                color: Color(Constants.primaryColor), strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 180,
          width: 220,
          color: Color(Constants.cardColor),
          child: const Icon(Icons.broken_image,
              color: Color(Constants.secondaryTextColor), size: 40),
        ),
      ),
    );
  }
}

// ── Document content ──────────────────────────────────────────────────────────

class _DocumentContent extends StatelessWidget {
  final String fileName;
  final int fileSize;
  final String fileExt;
  final String fileUrl;
  final bool isCurrentUser;
  final DateTime createdAt;

  const _DocumentContent({
    required this.fileName,
    required this.fileSize,
    required this.fileExt,
    required this.fileUrl,
    required this.isCurrentUser,
    required this.createdAt,
  });

  IconData get _fileIcon {
    switch (fileExt.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'mp3':
        return Icons.audio_file_rounded;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get _fileColor {
    switch (fileExt.toLowerCase()) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
        return Colors.blueAccent;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.amber;
      case 'mp3':
        return Colors.purple;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => OpenFilex.open(fileUrl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _fileColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_fileIcon, color: _fileColor, size: 26),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isNotEmpty ? fileName : 'File',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      fileExt.toUpperCase(),
                      style: TextStyle(
                          color: _fileColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    if (fileSize > 0) ...[
                      Text(' · ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11)),
                      Text(
                        _formatSize(fileSize),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Text content ──────────────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  final String text;
  final bool isCurrentUser;
  final bool seen;
  final bool delivered;
  final DateTime createdAt;

  const _TextContent({
    required this.text,
    required this.isCurrentUser,
    required this.seen,
    required this.delivered,
    required this.createdAt,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(createdAt),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 4),
              Icon(
                seen
                    ? Icons.done_all
                    : delivered
                        ? Icons.done_all
                        : Icons.done,
                size: 14,
                color: seen
                    ? Colors.blue
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Call log tile ─────────────────────────────────────────────────────────────

class _CallLogTile extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const _CallLogTile({required this.message, required this.isCurrentUser});

  String _formatDuration(int seconds) {
    if (seconds == 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = message.callType == 'video_call';
    final isMissed = message.callStatus == 'missed';
    final isDeclined = message.callStatus == 'declined';
    final isEnded = message.callStatus == 'ended';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isMissed) {
      statusColor = Colors.redAccent;
      statusIcon = isVideo ? Icons.videocam_off : Icons.phone_missed;
      statusText = isCurrentUser ? 'Missed call' : 'Missed call';
    } else if (isDeclined) {
      statusColor = Colors.orange;
      statusIcon = isVideo ? Icons.videocam_off : Icons.call_end;
      statusText = 'Declined';
    } else if (isEnded) {
      statusColor = Colors.greenAccent;
      statusIcon = isVideo ? Icons.videocam : Icons.call;
      final dur = _formatDuration(message.callDuration);
      statusText = dur.isNotEmpty ? dur : 'Call ended';
    } else {
      statusColor = Colors.white54;
      statusIcon = isVideo ? Icons.videocam : Icons.call;
      statusText = isVideo ? 'Video call' : 'Voice call';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color(Constants.surfaceColor).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 13),
              ),
              const SizedBox(width: 6),
              Text(
                '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Deleted bubble ────────────────────────────────────────────────────────────

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
                    size: 14, color: Colors.white.withValues(alpha: 0.4)),
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

// ── Reactions row ─────────────────────────────────────────────────────────────

class _ReactionsRow extends StatelessWidget {
  final List<MessageReaction> reactions;
  final String currentUserId;

  const _ReactionsRow({
    required this.reactions,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, int> counts = {};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return Wrap(
      spacing: 4,
      children: counts.entries.map((entry) {
        final isMine = reactions
            .any((r) => r.userId == currentUserId && r.emoji == entry.key);
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
            entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
    );
  }
}
