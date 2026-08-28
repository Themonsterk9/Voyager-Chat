import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/calling/call_manager.dart';
import '../../../core/calling/call_models.dart';
import '../../../core/permissions/permission_helper.dart';

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key, required this.recipientName});

  final String recipientName;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
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
    final hasMic = await PermissionHelper.instance.ensurePermission(
      context,
      Permission.microphone,
      title: 'Microphone Permission Required',
      rationale: 'Voyager Chat requires microphone access for voice calling.',
    );
    if (!hasMic && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice calls.'),
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
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          widget.recipientName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _callManager.state == CallState.connected
                            ? 'Connected • ${_formatDuration(_seconds)}'
                            : 'Ringing...',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: Colors.blueAccent.shade700,
                        child: Text(
                          widget.recipientName.isNotEmpty
                              ? widget.recipientName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Spacer(),
                      // Call Controls Overlay
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 32,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              iconSize: 32,
                              icon: Icon(
                                _callManager.isMuted
                                    ? Icons.mic_off
                                    : Icons.mic,
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
                            FloatingActionButton(
                              heroTag: 'endVoiceCall',
                              backgroundColor: Colors.red,
                              onPressed: () {
                                _callManager.endCall();
                                Navigator.pop(context);
                              },
                              child: const Icon(
                                Icons.call_end,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              iconSize: 32,
                              icon: Icon(
                                _callManager.isSpeakerOn
                                    ? Icons.volume_up
                                    : Icons.volume_down,
                                color: _callManager.isSpeakerOn
                                    ? Colors.blueAccent
                                    : Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _callManager.toggleSpeaker();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
