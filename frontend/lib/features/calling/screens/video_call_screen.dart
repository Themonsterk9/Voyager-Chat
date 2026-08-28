import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/calling/call_manager.dart';
import '../../../core/calling/call_models.dart';
import '../../../core/permissions/permission_helper.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key, required this.recipientName});

  final String recipientName;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallManager _callManager = CallManager.instance;
  late StreamSubscription<int> _durationSub;

  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _durationSub = _callManager.durationStream.listen((sec) {
      if (mounted) {
        setState(() {
          _seconds = sec;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCallPermissions();
    });

    if (_callManager.state == CallState.calling) {
      _callManager.acceptCall();
    }
  }

  Future<void> _checkCallPermissions() async {
    final hasCamera = await PermissionHelper.instance.ensurePermission(
      context,
      Permission.camera,
      title: 'Camera Permission Required',
      rationale: 'Voyager Chat requires camera access for video calling.',
    );

    if (!mounted) return;

    final hasMic = await PermissionHelper.instance.ensurePermission(
      context,
      Permission.microphone,
      title: 'Microphone Permission Required',
      rationale: 'Voyager Chat requires microphone access for video calling.',
    );

    if ((!hasCamera || !hasMic) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera and Microphone permissions are required for video calls.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _durationSub.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video Stream Container
          Container(
            color: Colors.grey.shade900,
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 12),
                Text(
                  'WebRTC Video Stream Active: ${widget.recipientName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '720p HD • ${_formatDuration(_seconds)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Local Picture-in-Picture Self Preview Overlay
          Positioned(
            top: 48,
            right: 16,
            child: Container(
              width: 110,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: _callManager.isCameraOn
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person, color: Colors.white70, size: 36),
                        SizedBox(height: 4),
                        Text(
                          'Self Preview',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    )
                  : const Center(
                      child: Icon(Icons.videocam_off, color: Colors.redAccent),
                    ),
            ),
          ),

          // Video Call Controls Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      _callManager.isMuted ? Icons.mic_off : Icons.mic,
                      color: _callManager.isMuted
                          ? Colors.redAccent
                          : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _callManager.toggleMute();
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _callManager.isCameraOn
                          ? Icons.videocam
                          : Icons.videocam_off,
                      color: _callManager.isCameraOn
                          ? Colors.white
                          : Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        _callManager.toggleCamera();
                      });
                    },
                  ),
                  FloatingActionButton(
                    heroTag: 'endVideoCall',
                    backgroundColor: Colors.red,
                    onPressed: () {
                      _callManager.endCall();
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _callManager.switchCamera();
                      });
                    },
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
