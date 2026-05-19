const Chat = require('../models/Chat');
const Message = require('../models/Message');
const User = require('../models/User');

// Get all chats for current user
const getChats = async (req, res) => {
  try {
    const chats = await Chat.find({
      members: req.user._id,
    })
      .populate('members', 'name email profilePic online lastSeen')
      .sort({ updatedAt: -1 });

    // Get other user info for each chat
    const chatsWithUserInfo = chats.map(chat => {
      const otherMember = chat.members.find(
        member => member._id.toString() !== req.user._id.toString()
      );
      const unreadCount = chat.unreadCount
        ? (chat.unreadCount.get(req.user._id.toString()) || 0)
        : 0;
      return {
        _id: chat._id,
        user: otherMember,
        lastMessage: chat.lastMessage,
        updatedAt: chat.updatedAt,
        unreadCount,
      };
    });

    res.json({ chats: chatsWithUserInfo });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get or create chat with another user
const getOrCreateChat = async (req, res) => {
  try {
    const { userId } = req.params;

    // Check if chat already exists
    let chat = await Chat.findOne({
      members: { $all: [req.user._id, userId] },
    }).populate('members', 'name email profilePic online lastSeen');

    if (!chat) {
      // Create new chat
      chat = new Chat({
        members: [req.user._id, userId],
      });
      await chat.save();
      await chat.populate('members', 'name email profilePic online lastSeen');
    }

    const otherMember = chat.members.find(
      member => member._id.toString() !== req.user._id.toString()
    );

    res.json({
      chat: {
        _id: chat._id,
        user: otherMember,
        lastMessage: chat.lastMessage,
        updatedAt: chat.updatedAt,
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get messages for a chat (exclude messages deleted for this user)
const getMessages = async (req, res) => {
  try {
    const { chatId } = req.params;

    const messages = await Message.find({
      chatId,
      deletedFor: { $ne: req.user._id },
    })
      .populate('senderId', 'name profilePic')
      .sort({ createdAt: 1 });

    res.json({ messages });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Delete a message
// - deleteType 'me'       → hide locally (add userId to deletedFor)
// - deleteType 'everyone' → mark deletedForEveryone (sender only)
const deleteMessage = async (req, res) => {
  try {
    const { messageId } = req.params;
    const { deleteType } = req.body; // 'me' | 'everyone'

    const message = await Message.findById(messageId);
    if (!message) return res.status(404).json({ error: 'Message not found' });

    if (deleteType === 'everyone') {
      // Only the sender can delete for everyone
      if (message.senderId.toString() !== req.user._id.toString()) {
        return res.status(403).json({ error: 'Only the sender can delete for everyone' });
      }
      message.deletedForEveryone = true;
      message.text = '';
      message.image = '';
      await message.save();
      return res.json({ message: 'Message deleted for everyone', data: message });
    }

    // Delete for me — add to deletedFor if not already present
    if (!message.deletedFor.includes(req.user._id)) {
      message.deletedFor.push(req.user._id);
      await message.save();
    }
    return res.json({ message: 'Message deleted for you' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Add or update a reaction on a message
const reactToMessage = async (req, res) => {
  try {
    const { messageId } = req.params;
    const { emoji } = req.body;

    if (!emoji) return res.status(400).json({ error: 'emoji is required' });

    const message = await Message.findById(messageId);
    if (!message) return res.status(404).json({ error: 'Message not found' });

    const userId = req.user._id.toString();
    const existingIndex = message.reactions.findIndex(
      (r) => r.userId.toString() === userId
    );

    if (existingIndex >= 0) {
      if (message.reactions[existingIndex].emoji === emoji) {
        // Same emoji — toggle off (remove reaction)
        message.reactions.splice(existingIndex, 1);
      } else {
        // Different emoji — update
        message.reactions[existingIndex].emoji = emoji;
      }
    } else {
      message.reactions.push({ userId: req.user._id, emoji });
    }

    await message.save();
    await message.populate('senderId', 'name profilePic');
    return res.json({ message });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Mark messages as seen
const markMessagesAsSeen = async (req, res) => {
  try {
    const { chatId } = req.params;

    await Message.updateMany(
      {
        chatId,
        senderId: { $ne: req.user._id },
        seen: false,
      },
      { seen: true }
    );

    // Reset unread count for this user
    await Chat.findByIdAndUpdate(chatId, {
      [`unreadCount.${req.user._id}`]: 0,
    });

    res.json({ message: 'Messages marked as seen' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Clear all messages in a chat
const clearChat = async (req, res) => {
  try {
    const { chatId } = req.params;

    // Verify requester is a member of the chat
    const chat = await Chat.findOne({
      _id: chatId,
      members: req.user._id,
    });

    if (!chat) {
      return res.status(403).json({ error: 'Not a member of this chat' });
    }

    await Message.deleteMany({ chatId });

    // Reset lastMessage and unreadCount for all members
    const resetUnread = {};
    chat.members.forEach(memberId => {
      resetUnread[`unreadCount.${memberId}`] = 0;
    });

    await Chat.findByIdAndUpdate(chatId, {
      lastMessage: '',
      ...resetUnread,
    });

    res.json({ message: 'Chat cleared' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get all users (for finding users to chat with)
const getAllUsers = async (req, res) => {
  try {
    const users = await User.find({
      _id: { $ne: req.user._id },
    }).select('name email profilePic online lastSeen');

    res.json({ users });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getChats,
  getOrCreateChat,
  getMessages,
  markMessagesAsSeen,
  getAllUsers,
  clearChat,
  deleteMessage,
  reactToMessage,
};
