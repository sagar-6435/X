# Real-Time Chat Application

A modern, full-stack real-time chat application built with Flutter (frontend) and Node.js/Express (backend), featuring Socket.IO for real-time communication, MongoDB for data storage, and Firebase Cloud Messaging for push notifications.

## Features

### Frontend (Flutter)
- Clean minimal UI with dark mode and glassmorphism effects
- Email/password authentication with persistent login
- Real-time messaging with Socket.IO
- Online/offline status indicators
- Typing indicators
- Read receipts (seen status)
- Image sharing in chat
- Profile picture upload
- Push notifications via FCM
- Responsive design with smooth animations

### Backend (Node.js + Express)
- RESTful API architecture
- JWT authentication
- Socket.IO real-time events
- MongoDB data storage
- Firebase Cloud Messaging integration
- Image upload with Multer
- Modular scalable structure

## Tech Stack

### Frontend
- Flutter
- Provider (State Management)
- Socket.IO Client
- Firebase Messaging
- HTTP
- Shared Preferences
- Image Picker
- Cached Network Image

### Backend
- Node.js
- Express
- MongoDB (Mongoose)
- Socket.IO
- JWT (JSON Web Tokens)
- Firebase Admin SDK
- Multer (File Uploads)
- Bcrypt (Password Hashing)

## Project Structure

```
├── server/                 # Backend
│   ├── config/            # Configuration files
│   │   ├── db.js         # MongoDB connection
│   │   └── firebase.js   # Firebase configuration
│   ├── controllers/       # Route controllers
│   │   ├── authController.js
│   │   └── chatController.js
│   ├── middleware/        # Custom middleware
│   │   ├── auth.js       # JWT authentication
│   │   └── upload.js     # Multer configuration
│   ├── models/           # MongoDB models
│   │   ├── User.js
│   │   ├── Chat.js
│   │   └── Message.js
│   ├── routes/           # API routes
│   │   ├── auth.js
│   │   ├── chat.js
│   │   └── upload.js
│   ├── sockets/          # Socket.IO events
│   │   └── socket.js
│   ├── uploads/          # Uploaded images
│   ├── .env.example      # Environment variables template
│   ├── package.json      # Dependencies
│   └── server.js         # Entry point
│
└── chat_app/             # Flutter Frontend
    ├── android/          # Android configuration
    ├── ios/             # iOS configuration
    ├── lib/
    │   ├── models/      # Data models
    │   │   ├── user.dart
    │   │   ├── message.dart
    │   │   └── chat.dart
    │   ├── providers/   # State management
    │   │   ├── auth_provider.dart
    │   │   └── chat_provider.dart
    │   ├── screens/     # UI screens
    │   │   ├── login_screen.dart
    │   │   ├── register_screen.dart
    │   │   ├── chat_list_screen.dart
    │   │   ├── chat_room_screen.dart
    │   │   └── users_screen.dart
    │   ├── services/    # API and services
    │   │   ├── api_service.dart
    │   │   ├── socket_service.dart
    │   │   └── notification_service.dart
    │   ├── utils/       # Utilities
    │   │   └── constants.dart
    │   ├── widgets/     # Reusable widgets
    │   │   └── message_bubble.dart
    │   └── main.dart    # App entry point
    └── pubspec.yaml     # Dependencies
```

## Setup Instructions

### Prerequisites

- Node.js (v14 or higher)
- MongoDB (local or MongoDB Atlas)
- Flutter SDK (v3.0 or higher)
- Firebase account (for FCM)
- Android Studio / Xcode (for mobile development)

### Backend Setup

1. **Navigate to server directory**
   ```bash
   cd server
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   - Copy `.env.example` to `.env`
   ```bash
   cp .env.example .env
   ```
   - Update `.env` with your values:
   ```env
   PORT=5000
   MONGODB_URI=mongodb://localhost:27017/chat-app
   JWT_SECRET=your_secure_jwt_secret_key_here
   FIREBASE_PROJECT_ID=your_firebase_project_id
   FIREBASE_PRIVATE_KEY=your_firebase_private_key
   FIREBASE_CLIENT_EMAIL=your_firebase_client_email
   ```

4. **Set up Firebase**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project
   - Enable Cloud Messaging
   - Generate a private key:
     - Go to Project Settings > Service Accounts
     - Click "Generate New Private Key"
     - Download the JSON file
   - Copy the values from the JSON to your `.env` file:
     - `project_id` → FIREBASE_PROJECT_ID
     - `private_key` → FIREBASE_PRIVATE_KEY (replace `\n` with actual newlines)
     - `client_email` → FIREBASE_CLIENT_EMAIL

5. **Create uploads directory**
   ```bash
   mkdir uploads
   ```

6. **Start the server**
   ```bash
   # Development mode (with auto-restart)
   npm run dev

   # Production mode
   npm start
   ```

   The server will run on `http://localhost:5000`

### Flutter Frontend Setup

1. **Navigate to chat_app directory**
   ```bash
   cd chat_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API URL**
   - Open `lib/utils/constants.dart`
   - Update the base URL to match your server:
   ```dart
   static const String baseUrl = 'http://10.0.2.2:5000/api';  // For Android emulator
   static const String socketUrl = 'http://10.0.2.2:5000';
   
   // For physical device or iOS simulator, use your computer's IP:
   // static const String baseUrl = 'http://YOUR_COMPUTER_IP:5000/api';
   // static const String socketUrl = 'http://YOUR_COMPUTER_IP:5000';
   ```

4. **Set up Firebase for Flutter**
   - Add `google-services.json` to `android/app/` (Android)
   - Add `GoogleService-Info.plist` to `ios/Runner/` (iOS)
   - Download these from Firebase Console > Project Settings

5. **Add Google Services plugin (Android)**
   - Add to `android/build.gradle`:
   ```gradle
   dependencies {
       classpath 'com.google.gms:google-services:4.3.15'
   }
   ```
   - Add to `android/app/build.gradle` (first line):
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

6. **Run the app**
   ```bash
   # For Android emulator
   flutter run

   # For iOS simulator
   flutter run -d ios

   # For specific device
   flutter devices
   flutter run -d <device_id>
   ```

## MongoDB Setup

### Option 1: Local MongoDB

1. Install MongoDB from [mongodb.com](https://www.mongodb.com/try/download/community)
2. Start MongoDB service:
   ```bash
   # Windows
   net start MongoDB

   # macOS/Linux
   sudo systemctl start mongod
   ```
3. Update `.env`:
   ```env
   MONGODB_URI=mongodb://localhost:27017/chat-app
   ```

### Option 2: MongoDB Atlas (Cloud)

1. Create account at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Create a free cluster
3. Create a database user
4. Whitelist your IP address (or use 0.0.0.0/0 for all IPs)
5. Get connection string:
   - Click "Connect" > "Connect your application"
   - Copy the connection string
6. Update `.env`:
   ```env
   MONGODB_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/chat-app
   ```

## API Endpoints

### Authentication

- `POST /api/auth/register` - Register new user
  - Body: `{ name, email, password }`
  
- `POST /api/auth/login` - Login user
  - Body: `{ email, password }`
  
- `GET /api/auth/me` - Get current user
  - Headers: `Authorization: Bearer <token>`
  
- `PUT /api/auth/profile` - Update profile
  - Headers: `Authorization: Bearer <token>`
  - Body: `{ name, profilePic }` (multipart/form-data)
  
- `PUT /api/auth/fcm-token` - Update FCM token
  - Headers: `Authorization: Bearer <token>`
  - Body: `{ fcmToken }`
  
- `POST /api/auth/logout` - Logout user
  - Headers: `Authorization: Bearer <token>`

### Chat

- `GET /api/chat/chats` - Get all chats
  - Headers: `Authorization: Bearer <token>`
  
- `GET /api/chat/chat/:userId` - Get or create chat with user
  - Headers: `Authorization: Bearer <token>`
  
- `GET /api/chat/messages/:chatId` - Get chat messages
  - Headers: `Authorization: Bearer <token>`
  
- `PUT /api/chat/messages/:chatId/seen` - Mark messages as seen
  - Headers: `Authorization: Bearer <token>`
  
- `GET /api/chat/users` - Get all users
  - Headers: `Authorization: Bearer <token>`

### Upload

- `POST /api/upload/image` - Upload image
  - Headers: `Authorization: Bearer <token>`
  - Body: `image` (multipart/form-data)

## Socket.IO Events

### Client → Server

- `join-chat` - Join a chat room
  - Data: `{ userId, chatId }`
  
- `send-message` - Send a message
  - Data: `{ chatId, senderId, text, image }`
  
- `typing` - User is typing
  - Data: `{ chatId, userId }`
  
- `stop-typing` - User stopped typing
  - Data: `{ chatId, userId }`
  
- `seen-message` - Mark messages as seen
  - Data: `{ chatId, userId }`

### Server → Client

- `receive-message` - New message received
  - Data: Message object
  
- `user-typing` - User is typing
  - Data: `{ userId }`
  
- `user-stop-typing` - User stopped typing
  - Data: `{ userId }`
  
- `messages-seen` - Messages marked as seen
  - Data: `{ chatId, userId }`
  
- `user-online` - User came online
  - Data: `{ userId }`
  
- `user-offline` - User went offline
  - Data: `{ userId }`

## Deployment

### Backend Deployment (Render/Railway)

#### Option 1: Render

1. Push code to GitHub
2. Create account at [render.com](https://render.com)
3. Create new Web Service
4. Connect GitHub repository
5. Configure:
   - Build Command: `npm install`
   - Start Command: `node server.js`
   - Environment Variables: Add all from `.env`
6. Deploy

#### Option 2: Railway

1. Push code to GitHub
2. Create account at [railway.app](https://railway.app)
3. New Project > Deploy from GitHub repo
4. Add environment variables
5. Deploy

### Frontend Deployment

#### Option 1: Build APK for Android

```bash
cd chat_app
flutter build apk --release
```

The APK will be in `build/app/outputs/flutter-apk/app-release.apk`

#### Option 2: Build App Bundle for Play Store

```bash
flutter build appbundle --release
```

The AAB will be in `build/app/outputs/bundle/release/app-release.aab`

#### Option 3: Build for iOS

```bash
flutter build ios --release
```

Then open Xcode and archive the app for App Store submission.

## Troubleshooting

### Backend Issues

**MongoDB Connection Error**
- Ensure MongoDB is running
- Check connection string in `.env`
- Verify IP whitelist in MongoDB Atlas

**Socket.IO Connection Issues**
- Check CORS settings in `server.js`
- Verify socket URL in Flutter constants
- Ensure firewall allows WebSocket connections

**Firebase FCM Not Working**
- Verify Firebase credentials in `.env`
- Check private key format (replace `\n` with actual newlines)
- Ensure FCM is enabled in Firebase Console

### Flutter Issues

**API Connection Failed**
- Update `baseUrl` in `lib/utils/constants.dart`
- For emulator: use `10.0.2.2` (Android) or `localhost` (iOS)
- For physical device: use your computer's IP address
- Ensure backend is running and accessible

**Notifications Not Working**
- Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
- Check notification permissions in device settings
- Ensure FCM token is being sent to backend

**Image Upload Failed**
- Check backend uploads directory exists
- Verify Multer configuration
- Ensure file size is under 5MB limit

## Security Considerations

1. **JWT Secret**: Use a strong, random JWT secret in production
2. **MongoDB**: Use authentication and enable IP whitelisting
3. **HTTPS**: Use HTTPS in production (SSL certificates)
4. **Environment Variables**: Never commit `.env` files
5. **Input Validation**: All inputs are validated on both client and server
6. **Password Hashing**: Passwords are hashed using bcrypt
7. **Rate Limiting**: Consider adding rate limiting for API endpoints

## Future Enhancements

- Group chats
- Voice/video calls
- Message reactions
- Message search
- Message encryption (end-to-end)
- File sharing (documents, videos)
- Voice messages
- User blocking
- Message deletion
- Online status history
- Push notification settings
- Dark/light theme toggle
- Multi-language support

## License

This project is for educational purposes. Feel free to use and modify as needed.

## Support

For issues or questions, please refer to the troubleshooting section or create an issue in the repository.
