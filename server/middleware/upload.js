const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  },
});

// Image-only upload
const imageUpload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    if (extname && mimetype) return cb(null, true);
    cb(new Error('Images only (jpeg, jpg, png, gif, webp)'));
  },
});

// Document upload (pdf, doc, docx, xls, xlsx, ppt, pptx, txt, zip, etc.)
const documentUpload = multer({
  storage,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25MB
  fileFilter: (req, file, cb) => {
    const allowedExts = /pdf|doc|docx|xls|xlsx|ppt|pptx|txt|zip|rar|7z|csv|mp3|mp4|mov|avi/;
    const extname = allowedExts.test(path.extname(file.originalname).toLowerCase());
    if (extname) return cb(null, true);
    cb(new Error('Unsupported file type'));
  },
});

module.exports = { imageUpload, documentUpload };
