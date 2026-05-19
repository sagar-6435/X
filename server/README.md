# Chat App Backend

Node.js + Express backend for real-time chat application with Socket.IO, MongoDB, and Firebase Cloud Messaging.

## Features

- RESTful API with Express
- JWT authentication
- Socket.IO real-time events
- MongoDB data persistence
- Firebase Cloud Messaging
- Image upload with Multer
- Modular architecture

## Installation

1. Install dependencies:
```bash
npm install
```

2. Configure environment variables:
```bash
cp .env.example .env
```

3. Update `.env` with your values:
```env
PORT=5000
MONGODB_URI=mongodb://localhost:27017/chat-app
JWT_SECRET=your_secure_jwt_secret_key_here
FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_PRIVATE_KEY=your_firebase_private_key
FIREBASE_CLIENT_EMAIL=your_firebase_client_email
```

4. Create uploads directory:
```bash
mkdir uploads
```

5. Start the server:
```bash
# Development
npm run dev

# Production
npm start
```

## API Documentation

See the main [README.md](../README.md) for complete API documentation.

## Project Structure

```
server/
├── config/           # Configuration files
├── controllers/      # Route controllers
├── middleware/       # Custom middleware
├── models/          # MongoDB models
├── routes/          # API routes
├── sockets/         # Socket.IO events
├── uploads/         # Uploaded images
└── server.js        # Entry point
```

## Dependencies

- express
- mongoose
- socket.io
- cors
- dotenv
- bcrypt
- jsonwebtoken
- firebase-admin
- multer
