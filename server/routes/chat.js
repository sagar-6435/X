const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const {
  getChats,
  getOrCreateChat,
  getMessages,
  markMessagesAsSeen,
  getAllUsers,
  clearChat,
  deleteMessage,
  reactToMessage,
} = require('../controllers/chatController');

// All routes are protected
router.get('/chats', auth, getChats);
router.get('/chat/:userId', auth, getOrCreateChat);
router.get('/messages/:chatId', auth, getMessages);
router.put('/messages/:chatId/seen', auth, markMessagesAsSeen);
router.get('/users', auth, getAllUsers);
router.delete('/chat/:chatId/clear', auth, clearChat);
router.delete('/message/:messageId', auth, deleteMessage);
router.post('/message/:messageId/react', auth, reactToMessage);

module.exports = router;
