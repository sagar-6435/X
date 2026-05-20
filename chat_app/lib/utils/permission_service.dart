import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request microphone permission for voice calls.
  /// Returns true if granted.
  static Future<bool> requestMicrophone(BuildContext context) async {
    return _request(
      context,
      permission: Permission.microphone,
      label: 'Microphone',
      reason: 'Microphone access is needed to make voice and video calls.',
    );
  }

  /// Request camera + microphone for video calls.
  /// Returns true only if both are granted.
  static Future<bool> requestCameraAndMicrophone(BuildContext context) async {
    final results = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraOk = results[Permission.camera]?.isGranted ?? false;
    final micOk = results[Permission.microphone]?.isGranted ?? false;

    if (!cameraOk || !micOk) {
      if (context.mounted) {
        _showDeniedDialog(
          context,
          label: 'Camera & Microphone',
          reason: 'Both camera and microphone access are needed for video calls.',
        );
      }
      return false;
    }
    return true;
  }

  /// Request storage / media permissions for picking images.
  /// Handles Android 13+ (READ_MEDIA_IMAGES) and older (READ_EXTERNAL_STORAGE).
  /// Returns true if granted.
  static Future<bool> requestPhotos(BuildContext context) async {
    // On Android 13+ use granular media permission; fall back to storage.
    final permission = await _photosPermission();
    return _request(
      context,
      permission: permission,
      label: 'Photos',
      reason: 'Photo library access is needed to share images.',
    );
  }

  /// Request storage permissions for picking documents.
  /// Returns true if granted.
  static Future<bool> requestStorage(BuildContext context) async {
    final permission = await _storagePermission();
    return _request(
      context,
      permission: permission,
      label: 'Storage',
      reason: 'Storage access is needed to share documents.',
    );
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static Future<bool> _request(
    BuildContext context, {
    required Permission permission,
    required String label,
    required String reason,
  }) async {
    var status = await permission.status;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) _showDeniedDialog(context, label: label, reason: reason);
      return false;
    }

    status = await permission.request();

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      _showDeniedDialog(context, label: label, reason: reason);
    }
    return false;
  }

  static void _showDeniedDialog(
    BuildContext context, {
    required String label,
    required String reason,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label permission required'),
        content: Text(
          '$reason\n\nPlease enable it in Settings → App permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Returns the correct photos permission for the current Android version.
  static Future<Permission> _photosPermission() async {
    // permission_handler exposes READ_MEDIA_IMAGES on SDK 33+
    // and falls back gracefully on older versions.
    return Permission.photos;
  }

  /// Returns the correct storage permission for the current Android version.
  static Future<Permission> _storagePermission() async {
    return Permission.storage;
  }
}
