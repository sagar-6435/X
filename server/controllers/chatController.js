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
      return {
        _id: chat._id,
        user: otherMember,
        lastMessage: chat.lastMessage,
        updatedAt: chat.updatedAt,
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

// Get messages for a chat
const getMessages = async (req, res) => {
  try {
    const { chatId } = req.params;

    const messages = await Message.find({ chatId })
      .populate('senderId', 'name profilePic')
      .sort({ createdAt: 1 });

    res.json({ messages });
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

    res.json({ message: 'Messages marked as seen' });
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
};
