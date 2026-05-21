import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../utils/constants.dart';
import '../utils/permission_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String userName;
  final String? userProfilePic;
  final String calleeId;
  final String callerId;
  final String chatId;
  final bool isCaller;
  final dynamic incomingOffer;

  const VideoCallScreen({
    super.key,
    required this.userName,
    this.userProfilePic,
    required this.calleeId,
    required this.callerId,
    required this.chatId,
    this.isCaller = true,
    this.incomingOffer,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _callConnected = false;
  bool _callEnded = false;
  int _callSeconds = 0;
  Timer? _callTimer;

  // Buffer ICE candidates that arrive before remote description is set
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;

  final _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  String get _remoteUserId =>
      widget.isCaller ? widget.calleeId : widget.callerId;

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _setupCallbacks();
    await _initCall();
  }

  void _setupCallbacks() {
    final provider = Provider.of<ChatProvider>(context, listen: false);
    provider.onCallAnswered = (answer) async {
      if (_peerConnection == null) return;
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
      _remoteDescriptionSet = true;
      await _drainCandidates();
      setState(() => _callConnected = true);
      _startTimer();
    };
    provider.onIceCandidate = (candidate) async {
      final c = RTCIceCandidate(
        candidate['candidate'],
        candidate['sdpMid'],
        candidate['sdpMLineIndex'],
      );
      if (_remoteDescriptionSet && _peerConnection != null) {
        await _peerConnection!.addCandidate(c);
      } else {
        _pendingCandidates.add(c);
      }
    };
    provider.onCallDeclined = () => _handleCallDeclined();
    provider.onCallEnded = () => _handleRemoteHangup();
  }

  Future<void> _drainCandidates() async {
    for (final c in _pendingCandidates) {
      await _peerConnection?.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  Future<void> _initCall() async {
    final granted = await PermissionService.requestCameraAndMicrophone(context);
    if (!granted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _localRenderer.srcObject = _localStream;

    _peerConnection = await createPeerConnection(_iceServers);

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() => _remoteRenderer.srcObject = event.streams[0]);
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      Provider.of<ChatProvider>(context, listen: false).sendIceCandidate(
        targetUserId: _remoteUserId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _callConnected = true);
        _startTimer();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Only end on genuine failure — CLOSED fires on normal dispose, ignore it
        _endCall();
      }
    };

    if (widget.isCaller) {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      Provider.of<ChatProvider>(context, listen: false).initiateCall(
        calleeId: widget.calleeId,
        chatId: widget.chatId,
        callType: 'video_call',
        offer: {'sdp': offer.sdp, 'type': offer.type},
      );
    } else {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(
            widget.incomingOffer['sdp'], widget.incomingOffer['type']),
      );
      _remoteDescriptionSet = true;
      await _drainCandidates();
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      Provider.of<ChatProvider>(context, listen: false).answerCall(
        callerId: widget.callerId,
        answer: {'sdp': answer.sdp, 'type': answer.type},
      );
      setState(() => _callConnected = true);
      _startTimer();
    }
    setState(() {});
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  void _toggleMute() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = _isMuted);
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleCamera() {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = _isCameraOff);
    setState(() => _isCameraOff = !_isCameraOff);
  }

  Future<void> _switchCamera() async {
    if (_localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
      setState(() => _isFrontCamera = !_isFrontCamera);
    }
  }

  void _endCall() {
    if (_callEnded) return;
    setState(() => _callEnded = true);
    _callTimer?.cancel();
    Provider.of<ChatProvider>(context, listen: false).endCall(
      targetUserId: _remoteUserId,
      chatId: widget.chatId,
      callType: 'video_call',
      callDuration: _callSeconds,
    );
    _peerConnection?.close();
    _localStream?.dispose();
    if (mounted) Navigator.pop(context);
  }

  void _handleCallDeclined() {
    if (_callEnded) return;
    setState(() => _callEnded = true);
    _callTimer?.cancel();
    _peerConnection?.close();
    _localStream?.dispose();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Call declined')));
      Navigator.pop(context);
    }
  }

  void _handleRemoteHangup() {
    if (_callEnded) return;
    setState(() => _callEnded = true);
    _callTimer?.cancel();
    _peerConnection?.close();
    _localStream?.dispose();
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          if (_callConnected && _remoteRenderer.srcObject != null)
            Positioned.fill(
              child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            )
          else
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1a1a2e),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(Constants.primaryColor),
                        ),
                        child: Center(
                          child: Text(
                            widget.userName[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(widget.userName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        widget.isCaller ? 'Calling...' : 'Incoming video call',
                        style: const TextStyle(color: Colors.white60, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Local video (picture-in-picture)
          Positioned(
            top: 60,
            right: 16,
            child: GestureDetector(
              onTap: _switchCamera,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 1.5),
                  color: Colors.black54,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _localStream != null && !_isCameraOff
                      ? RTCVideoView(_localRenderer,
                          mirror: _isFrontCamera,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                      : const Center(
                          child: Icon(Icons.videocam_off, color: Colors.white54, size: 32)),
                ),
              ),
            ),
          ),

          // Top bar — name + timer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  if (_callConnected)
                    Text(_formatDuration(_callSeconds),
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _VideoCallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    active: _isMuted,
                    onTap: _toggleMute,
                    label: _isMuted ? 'Unmute' : 'Mute',
                  ),
                  _VideoCallButton(
                    icon: Icons.call_end,
                    active: true,
                    activeColor: Colors.redAccent,
                    onTap: _endCall,
                    label: 'End',
                    size: 68,
                  ),
                  _VideoCallButton(
                    icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    active: _isCameraOff,
                    onTap: _toggleCamera,
                    label: _isCameraOff ? 'Cam off' : 'Camera',
                  ),
                  _VideoCallButton(
                    icon: Icons.flip_camera_ios,
                    active: false,
                    onTap: _switchCamera,
                    label: 'Flip',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCallButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  final String label;
  final double size;

  const _VideoCallButton({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.label,
    this.activeColor,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? (activeColor ?? Colors.redAccent)
        : Colors.white.withValues(alpha: 0.2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}
