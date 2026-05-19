const Message = require('../models/Message');
const Chat = require('../models/Chat');
const User = require('../models/User');
const admin = require('../config/firebase');

// Store online users
const onlineUsers = new Map();

const setupSocket = (io) => {
  io.on('connection', (socket) => {
    console.log('User connected:', socket.id);

    // Join chat room
    socket.on('join-chat', async ({ userId, chatId }) => {
      try {
        socket.join(chatId);
        onlineUsers.set(userId, socket.id);
        
        // Update user online status
        await User.findByIdAndUpdate(userId, { online: true });
        
        // Notify others in the chat
        socket.to(chatId).emit('user-online', { userId });
      } catch (error) {
        console.error('Error joining chat:', error);
      }
    });

    // Send message
    socket.on('send-message', async (data) => {
      try {
        const { chatId, senderId, text, image } = data;

        // Create new message
        const message = new Message({
          chatId,
          senderId,
          text,
          image,
          seen: false,
        });
        await message.save();

        // Update chat's last message
        await Chat.findByIdAndUpdate(chatId, {
          lastMessage: text || '[Image]',
          updatedAt: new Date(),
        });

        // Populate sender info
        await message.populate('senderId', 'name profilePic');

        // Send to all users in the chat
        io.to(chatId).emit('receive-message', message);

        // Send push notification to offline users
        const chat = await Chat.findById(chatId).populate('members');
        const recipient = chat.members.find(
          (m) => m._id.toString() !== senderId
        );

        if (recipient && !recipient.online && recipient.fcmToken) {
          const sender = await User.findById(senderId);
          await admin.messaging().send({
            token: recipient.fcmToken,
            notification: {
              title: sender.name,
              body: text || 'Sent an image',
            },
            data: {
              chatId: chatId.toString(),
              type: 'message',
            },
          });
        }
      } catch (error) {
        console.error('Error sending message:', error);
      }
    });

    // Typing indicator
    socket.on('typing', ({ chatId, userId }) => {
      socket.to(chatId).emit('user-typing', { userId });
    });

    socket.on('stop-typing', ({ chatId, userId }) => {
      socket.to(chatId).emit('user-stop-typing', { userId });
    });

    // Mark message as seen
    socket.on('seen-message', async ({ chatId, userId }) => {
      try {
        await Message.updateMany(
          {
            chatId,
            senderId: { $ne: userId },
            seen: false,
          },
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
        // Find and remove user from online users
        for (const [userId, socketId] of onlineUsers.entries()) {
          if (socketId === socket.id) {
            onlineUsers.delete(userId);
            
            // Update user offline status
            await User.findByIdAndUpdate(userId, {
              online: false,
              lastSeen: new Date(),
            });
            
            // Notify all chats the user is in
            const chats = await Chat.find({ members: userId });
            chats.forEach((chat) => {
              io.to(chat._id.toString()).emit('user-offline', { userId });
            });
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
