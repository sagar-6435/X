import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../utils/constants.dart';
import '../utils/permission_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String userName;
  final String userInitial;
  final String profilePic;
  final String calleeId;
  final String callerId;
  final String chatId;
  /// true = we are the caller, false = we are answering
  final bool isCaller;
  /// SDP offer from caller (only set when isCaller == false)
  final dynamic incomingOffer;

  const VoiceCallScreen({
    super.key,
    required this.userName,
    required this.userInitial,
    required this.profilePic,
    required this.calleeId,
    required this.callerId,
    required this.chatId,
    this.isCaller = true,
    this.incomingOffer,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
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
    _initCall();
    _setupCallbacks();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _localStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  String get _remoteUserId =>
      widget.isCaller ? widget.calleeId : widget.callerId;

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
    final granted = await PermissionService.requestMicrophone(context);
    if (!granted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _localStream = await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});

    _peerConnection = await createPeerConnection(_iceServers);

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

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
      final offer = await _peerConnection!.createOffer({'offerToReceiveAudio': true});
      await _peerConnection!.setLocalDescription(offer);
      Provider.of<ChatProvider>(context, listen: false).initiateCall(
        calleeId: widget.calleeId,
        chatId: widget.chatId,
        callType: 'voice_call',
        offer: {'sdp': offer.sdp, 'type': offer.type},
      );
    } else {
      // Answering incoming call
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

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  void _endCall() {
    if (_callEnded) return;
    setState(() => _callEnded = true);
    _callTimer?.cancel();
    Provider.of<ChatProvider>(context, listen: false).endCall(
      targetUserId: _remoteUserId,
      chatId: widget.chatId,
      callType: 'voice_call',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call declined')),
      );
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
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Avatar
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(Constants.primaryColor),
                boxShadow: [
                  BoxShadow(
                    color: Color(Constants.primaryColor).withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: widget.profilePic.isNotEmpty
                  ? ClipOval(
                      child: Image.network(widget.profilePic, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                                child: Text(widget.userInitial.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 44,
                                        fontWeight: FontWeight.bold)),
                              )))
                  : Center(
                      child: Text(widget.userInitial.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 28),
            Text(widget.userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              _callConnected
                  ? _formatDuration(_callSeconds)
                  : widget.isCaller
                      ? 'Calling...'
                      : 'Incoming voice call',
              style: TextStyle(
                  color: _callConnected ? Colors.greenAccent : Colors.white60,
                  fontSize: 16),
            ),
            const Spacer(),
            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    color: _isMuted
                        ? Colors.redAccent
                        : Colors.white.withValues(alpha: 0.15),
                    onTap: _toggleMute,
                  ),
                  _CallButton(
                    icon: Icons.call_end,
                    label: 'End',
                    color: Colors.redAccent,
                    size: 72,
                    iconSize: 34,
                    onTap: _endCall,
                  ),
                  _CallButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                    color: _isSpeakerOn
                        ? Color(Constants.primaryColor)
                        : Colors.white.withValues(alpha: 0.15),
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 60,
    this.iconSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}
