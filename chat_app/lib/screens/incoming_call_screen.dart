import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callerName;
  final String callerProfilePic;
  final String callerId;
  final String calleeId;
  final String chatId;
  final String callType; // 'voice_call' | 'video_call'
  final dynamic offer;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerProfilePic,
    required this.callerId,
    required this.calleeId,
    required this.chatId,
    required this.callType,
    required this.offer,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = callType == 'video_call';

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            // Caller avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(Constants.primaryColor),
                boxShadow: [
                  BoxShadow(
                    color: Color(Constants.primaryColor).withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: callerProfilePic.isNotEmpty
                  ? ClipOval(
                      child: Image.network(callerProfilePic,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                                child: Text(callerName[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold)),
                              )))
                  : Center(
                      child: Text(callerName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 32),
            Text(callerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: Colors.white60,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isVideo ? 'Incoming video call' : 'Incoming voice call',
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ],
            ),
            const Spacer(),
            // Accept / Decline buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end,
                              color: Colors.white, size: 32),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Decline',
                          style: TextStyle(color: Colors.white60, fontSize: 14)),
                    ],
                  ),
                  // Accept
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isVideo
                                  ? VideoCallScreen(
                                      userName: callerName,
                                      userProfilePic: callerProfilePic,
                                      calleeId: calleeId,
                                      callerId: callerId,
                                      chatId: chatId,
                                      isCaller: false,
                                      incomingOffer: offer,
                                    )
                                  : VoiceCallScreen(
                                      userName: callerName,
                                      userInitial: callerName[0],
                                      profilePic: callerProfilePic,
                                      calleeId: calleeId,
                                      callerId: callerId,
                                      chatId: chatId,
                                      isCaller: false,
                                      incomingOffer: offer,
                                    ),
                            ),
                          );
                        },
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam : Icons.call,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Accept',
                          style: TextStyle(color: Colors.white60, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
