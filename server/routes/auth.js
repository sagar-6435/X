const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');
const {
  register,
  login,
  getCurrentUser,
  updateProfile,
  updateFcmToken,
  logout,
} = require('../controllers/authController');

// Public routes
router.post('/register', register);
router.post('/login', login);

// Protected routes
router.get('/me', auth, getCurrentUser);
router.put('/profile', auth, upload.single('profilePic'), updateProfile);
router.put('/fcm-token', auth, updateFcmToken);
router.post('/logout', auth, logout);

module.exports = router;
