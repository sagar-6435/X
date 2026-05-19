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
        const { chatId, senderId, text, image } = data;

        // Save to DB — this is the source of truth for history
        const message = new Message({
          chatId,
          senderId,
          text: text || '',
          image: image || '',
          seen: false,
          delivered: false,
        });
        await message.save();

        // Find recipient before any async work
        const chat = await Chat.findById(chatId);
        let recipientId = null;
        let recipientSocketId = null;
        if (chat) {
          recipientId = chat.members.find(
            (m) => m.toString() !== senderId
          );
          if (recipientId) {
            recipientSocketId = onlineUsers.get(recipientId.toString());
          }
        }

        // Mark as delivered if recipient is online
        if (recipientSocketId) {
          message.delivered = true;
          await message.save();
        }

        // Increment unread count for recipient
        if (recipientId) {
          await Chat.findByIdAndUpdate(chatId, {
            lastMessage: text || '[Image]',
            updatedAt: new Date(),
            $inc: { [`unreadCount.${recipientId}`]: 1 },
          });
        } else {
          await Chat.findByIdAndUpdate(chatId, {
            lastMessage: text || '[Image]',
            updatedAt: new Date(),
          });
        }

        // Populate sender info
        await message.populate('senderId', 'name profilePic');

        // Emit to ALL in room (including sender so optimistic msg gets real _id)
        io.to(chatId).emit('receive-message', message);

        // Notify sender that message was delivered (if recipient is online)
        if (recipientSocketId) {
          const senderSocketId = onlineUsers.get(senderId);
          if (senderSocketId) {
            io.to(senderSocketId).emit('message-delivered', {
              messageId: message._id.toString(),
            });
          }
        }

        // Also emit to recipient's personal socket if they're online but not in room
        if (recipientSocketId) {
          io.to(recipientSocketId).emit('new-message-notification', {
            chatId,
            message,
          });
        }
      } catch (error) {
        console.error('Error sending message:', error);
      }
    });

    // Typing indicators
    socket.on('typing', ({ chatId, userId }) => {
      socket.to(chatId).emit('user-typing', { userId });
    });

    socket.on('stop-typing', ({ chatId, userId }) => {
      socket.to(chatId).emit('user-stop-typing', { userId });
    });

    // Mark messages as seen
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

    // Disconnect
    socket.on('disconnect', async () => {
      try {
        for (const [userId, socketId] of onlineUsers.entries()) {
          if (socketId === socket.id) {
            onlineUsers.delete(userId);
            await User.findByIdAndUpdate(userId, {
              online: false,
              lastSeen: new Date(),
            });
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

module.exports = setupSocket;
