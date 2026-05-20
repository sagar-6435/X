const express = require('express');
const router = express.Router();
const path = require('path');
const auth = require('../middleware/auth');
const { imageUpload, documentUpload } = require('../middleware/upload');

router.post('/image', auth, imageUpload.single('image'), (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    const imageUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    res.json({ imageUrl });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/document', auth, documentUpload.single('document'), (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    const originalName = req.file.originalname;
    const fileSize = req.file.size;
    const ext = path.extname(originalName).toLowerCase().replace('.', '');
    res.json({ fileUrl, originalName, fileSize, ext });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
