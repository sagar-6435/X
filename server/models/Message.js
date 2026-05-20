const mongoose = require('mongoose');

const reactionSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  emoji: {
    type: String,
    required: true,
  },
}, { _id: false });

const messageSchema = new mongoose.Schema({
  chatId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Chat',
    required: true,
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  text: { type: String, default: '' },
  image: { type: String, default: '' },
  // Document fields
  fileUrl: { type: String, default: '' },
  fileName: { type: String, default: '' },
  fileSize: { type: Number, default: 0 },
  fileExt: { type: String, default: '' },
  // Call fields: 'voice_call' | 'video_call'
  callType: { type: String, default: '' },
  // 'missed' | 'declined' | 'ended'
  callStatus: { type: String, default: '' },
  callDuration: { type: Number, default: 0 }, // seconds
  seen: { type: Boolean, default: false },
  delivered: { type: Boolean, default: false },
  deletedFor: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  deletedForEveryone: { type: Boolean, default: false },
  reactions: [reactionSchema],
  createdAt: { type: Date, default: Date.now },
}, { timestamps: true });

module.exports = mongoose.model('Message', messageSchema);
