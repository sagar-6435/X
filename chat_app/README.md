# Chat App Flutter

Flutter mobile application for real-time chat with modern UI, Socket.IO integration, and Firebase notifications.

## Features

- Clean minimal UI with dark mode
- Email/password authentication
- Real-time messaging
- Online/offline status
- Typing indicators
- Read receipts
- Image sharing
- Push notifications
- Profile pictures

## Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Configure API URL in `lib/utils/constants.dart`:
```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';  // Android emulator
static const String socketUrl = 'http://10.0.2.2:5000';
```

3. Add Firebase configuration files:
   - `google-services.json` to `android/app/` (Android)
   - `GoogleService-Info.plist` to `ios/Runner/` (iOS)

4. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── models/          # Data models
├── providers/       # State management
├── screens/         # UI screens
├── services/        # API and services
├── utils/          # Utilities
├── widgets/        # Reusable widgets
└── main.dart       # App entry point
```

## Dependencies

- provider
- http
- shared_preferences
- socket_io_client
- firebase_messaging
- flutter_local_notifications
- image_picker
- cached_network_image
- intl

## Building

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Configuration

### Android

Add to `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Add to `android/build.gradle`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
}
```

### iOS

Enable capabilities in Xcode:
- Push Notifications
- Background Modes > Remote notifications

## API Connection

For different environments, update `lib/utils/constants.dart`:

- **Android Emulator**: `http://10.0.2.2:5000`
- **iOS Simulator**: `http://localhost:5000`
- **Physical Device**: `http://YOUR_COMPUTER_IP:5000`

## Troubleshooting

See the main [README.md](../README.md) for troubleshooting guide.
