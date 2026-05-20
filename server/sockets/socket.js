const Message = require('../models/Message');
const Chat = require('../models/Chat');
const User = require('../models/User');

// userId -> socketId
const onlineUsers = new Map();

const setupSocket = (io) => {
  io.on('connection', (socket) => {
    console.log('User connected:', socket.id);

    // User comes online — register them globally
    socket.on('user-online', async ({ userId }) => {
      onlineUsers.set(userId, socket.id);
      await User.findByIdAndUpdate(userId, { online: true });
      socket.broadcast.emit('user-status', { userId, online: true });
    });

    // Join a specific chat room
    socket.on('join-chat', async ({ userId, chatId }) => {
      socket.join(chatId);
      onlineUsers.set(userId, socket.id);
      await User.findByIdAndUpdate(userId, { online: true });
      socket.to(chatId).emit('user-online', { userId });
    });

    // Send message — always saved to DB regardless of recipient online status
    socket.on('send-message', async (data) => {
      try {
        const { chatId, senderId, text, image, fileUrl, fileName, fileSize, fileExt } = data;

        const message = new Message({
          chatId,
          senderId,
          text: text || '',
          image: image || '',
          fileUrl: fileUrl || '',
          fileName: fileName || '',
          fileSize: fileSize || 0,
          fileExt: fileExt || '',
          seen: false,
          delivered: false,
        });
        await message.save();

        const chat = await Chat.findById(chatId);
        let recipientId = null;
        let recipientSocketId = null;
        if (chat) {
          recipientId = chat.members.find((m) => m.toString() !== senderId);
          if (recipientId) {
            recipientSocketId = onlineUsers.get(recipientId.toString());
          }
        }

        if (recipientSocketId) {
          message.delivered = true;
          await message.save();
        }

        const lastMsg = text || (image ? '[Image]' : fileName ? `[File] ${fileName}` : '[Message]');
        if (recipientId) {
          await Chat.findByIdAndUpdate(chatId, {
            lastMessage: lastMsg,
            updatedAt: new Date(),
            $inc: { [`unreadCount.${recipientId}`]: 1 },
          });
        } else {
          await Chat.findByIdAndUpdate(chatId, { lastMessage: lastMsg, updatedAt: new Date() });
        }

        await message.populate('senderId', 'name profilePic');
        io.to(chatId).emit('receive-message', message);

        if (recipientSocketId) {
          const senderSocketId = onlineUsers.get(senderId);
          if (senderSocketId) {
            io.to(senderSocketId).emit('message-delivered', { messageId: message._id.toString() });
          }
          io.to(recipientSocketId).emit('new-message-notification', { chatId, message });
        }
      } catch (error) {
        console.error('Error sending message:', error);
      }
    });

    // ── WebRTC Signaling ────────────────────────────────────────────────────

    // Caller initiates a call
    socket.on('call-user', async ({ callerId, calleeId, chatId, callType, offer }) => {
      const calleeSocketId = onlineUsers.get(calleeId);
      if (calleeSocketId) {
        io.to(calleeSocketId).emit('incoming-call', {
          callerId,
          chatId,
          callType,
          offer,
        });
      } else {
        // Callee offline — save missed call message
        socket.emit('call-failed', { reason: 'User is offline' });
        await _saveCallMessage({ chatId, senderId: callerId, callType, callStatus: 'missed' });
      }
    });

    // Callee answers
    socket.on('call-answer', ({ callerId, calleeId, answer }) => {
      const callerSocketId = onlineUsers.get(callerId);
      if (callerSocketId) {
        io.to(callerSocketId).emit('call-answered', { answer });
      }
    });

    // ICE candidate exchange
    socket.on('ice-candidate', ({ targetUserId, candidate }) => {
      const targetSocketId = onlineUsers.get(targetUserId);
      if (targetSocketId) {
        io.to(targetSocketId).emit('ice-candidate', { candidate });
      }
    });

    // Call declined by callee
    socket.on('call-declined', async ({ callerId, calleeId, chatId, callType }) => {
      const callerSocketId = onlineUsers.get(callerId);
      if (callerSocketId) {
        io.to(callerSocketId).emit('call-declined');
      }
      await _saveCallMessage({ chatId, senderId: callerId, callType, callStatus: 'declined' });
    });

    // Call ended by either party
    socket.on('call-ended', async ({ targetUserId, chatId, callType, callDuration, senderId }) => {
      const targetSocketId = onlineUsers.get(targetUserId);
      if (targetSocketId) {
        io.to(targetSocketId).emit('call-ended');
      }
      await _saveCallMessage({ chatId, senderId, callType, callStatus: 'ended', callDuration });
    });

    // ── Message management ──────────────────────────────────────────────────

    socket.on('delete-message', async ({ messageId, deleteType, userId, chatId }) => {
      try {
        const message = await Message.findById(messageId);
        if (!message) return;
        if (deleteType === 'everyone') {
          if (message.senderId.toString() !== userId) return;
          message.deletedForEveryone = true;
          message.text = '';
          message.image = '';
          message.fileUrl = '';
          await message.save();
          io.to(chatId).emit('message-deleted', { messageId, deleteType: 'everyone', chatId });
        } else {
          if (!message.deletedFor.map((id) => id.toString()).includes(userId)) {
            message.deletedFor.push(userId);
            await message.save();
          }
        }
      } catch (error) {
        console.error('Error deleting message:', error);
      }
    });

    socket.on('react-message', async ({ messageId, userId, emoji, chatId }) => {
      try {
        const message = await Message.findById(messageId);
        if (!message) return;
        const existingIndex = message.reactions.findIndex((r) => r.userId.toString() === userId);
        if (existingIndex >= 0) {
          if (message.reactions[existingIndex].emoji === emoji) {
            message.reactions.splice(existingIndex, 1);
          } else {
            message.reactions[existingIndex].emoji = emoji;
          }
        } else {
          message.reactions.push({ userId, emoji });
        }
        await message.save();
        await message.populate('senderId', 'name profilePic');
        io.to(chatId).emit('message-reacted', { messageId, reactions: message.reactions, chatId });
      } catch (error) {
        console.error('Error reacting to message:', error);
      }
    });

    socket.on('typing', ({ chatId, userId }) => {
      socket.to(chatId).emit('user-typing', { userId });
    });

    socket.on('stop-typing', ({ chatId, userId }) => {
      socket.to(chatId).emit('user-stop-typing', { userId });
    });

    socket.on('seen-message', async ({ chatId, userId }) => {
      try {
        await Message.updateMany(
          { chatId, senderId: { $ne: userId }, seen: false },
          { seen: true }
        );
        io.to(chatId).emit('messages-seen', { chatId, userId });
      } catch (error) {
        console.error('Error marking messages as seen:', error);
      }
    });

    socket.on('disconnect', async () => {
      try {
        for (const [userId, socketId] of onlineUsers.entries()) {
          if (socketId === socket.id) {
            onlineUsers.delete(userId);
            await User.findByIdAndUpdate(userId, { online: false, lastSeen: new Date() });
            socket.broadcast.emit('user-status', { userId, online: false });
            break;
          }
        }
        console.log('User disconnected:', socket.id);
      } catch (error) {
        console.error('Error on disconnect:', error);
      }
    });
  });
};

async function _saveCallMessage({ chatId, senderId, callType, callStatus, callDuration = 0 }) {
  try {
    const message = new Message({
      chatId,
      senderId,
      callType,
      callStatus,
      callDuration,
    });
    await message.save();
    const lastMsg = callType === 'video_call' ? '[Video Call]' : '[Voice Call]';
    await Chat.findByIdAndUpdate(chatId, { lastMessage: lastMsg, updatedAt: new Date() });
  } catch (e) {
    console.error('Error saving call message:', e);
  }
}

module.exports = setupSocket;
