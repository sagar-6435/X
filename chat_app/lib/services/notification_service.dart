// Notifications disabled — Firebase not configured
class NotificationService {
  Future<void> initialize() async {}
  Future<String?> getFcmToken() async => null;
}
