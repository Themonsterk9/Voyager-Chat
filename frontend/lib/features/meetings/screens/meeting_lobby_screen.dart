import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/meetings/meeting_models.dart';
import '../../../core/meetings/meeting_service.dart';
import '../../../core/permissions/permission_helper.dart';

class MeetingLobbyScreen extends StatefulWidget {
  const MeetingLobbyScreen({super.key, required this.meetingId});

  final String meetingId;

  @override
  State<MeetingLobbyScreen> createState() => _MeetingLobbyScreenState();
}

class _MeetingLobbyScreenState extends State<MeetingLobbyScreen> {
  final MeetingService _meetingService = MeetingService.instance;

  bool _isMicOn = true;
  bool _isCamOn = true;

  @override
  void initState() {
    super.initState();
    _meetingService.joinMeetingLobby(
      meetingId: widget.meetingId,
      userId: 'local-user',
      displayName: 'Local Voyager User',
    );
  }

  @override
  Widget build(BuildContext context) {
    final participants = _meetingService.getParticipants(widget.meetingId);
    final me = participants.firstWhere(
      (p) => p.userId == 'local-user',
      orElse: () => const MeetingParticipant(
        userId: 'local-user',
        displayName: 'Local Voyager User',
      ),
    );

    final waitingList = participants
        .where((p) => !p.isAdmitted && p.userId != 'local-user')
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Lobby & Waiting Room')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Preview Box
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isCamOn ? Icons.videocam : Icons.videocam_off,
                      size: 64,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCamOn ? 'Camera Preview Active' : 'Camera Muted',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Quick Control Toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _isMicOn ? Icons.mic : Icons.mic_off,
                    color: _isMicOn ? Colors.greenAccent : Colors.redAccent,
                  ),
                  onPressed: () => setState(() => _isMicOn = !_isMicOn),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    _isCamOn ? Icons.videocam : Icons.videocam_off,
                    color: _isCamOn ? Colors.blueAccent : Colors.redAccent,
                  ),
                  onPressed: () => setState(() => _isCamOn = !_isCamOn),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Waiting Room Status
            if (!me.isAdmitted && me.role != MeetingRole.host)
              const Card(
                color: Colors.amber,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top, color: Colors.black),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Waiting for the host to admit you to the meeting...',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Host Waiting Room Queue
            if (waitingList.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WAITING ROOM QUEUE',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              ...waitingList.map(
                (p) => ListTile(
                  title: Text(p.displayName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                        ),
                        onPressed: () {
                          _meetingService.admitParticipant(
                            widget.meetingId,
                            p.userId,
                          );
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () {
                          _meetingService.rejectParticipant(
                            widget.meetingId,
                            p.userId,
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.video_call),
              label: const Text(
                'Enter Meeting Room',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final nav = GoRouter.of(context);
                await PermissionHelper.instance.ensurePermission(
                  context,
                  Permission.camera,
                  title: 'Camera Permission Required',
                  rationale: 'Voyager Chat requires camera access for meetings.',
                );
                if (!mounted || !context.mounted) return;

                await PermissionHelper.instance.ensurePermission(
                  context,
                  Permission.microphone,
                  title: 'Microphone Permission Required',
                  rationale: 'Voyager Chat requires microphone access for meetings.',
                );
                if (!mounted) return;

                nav.push('/meeting/room/${widget.meetingId}');
              },
            ),
          ],
        ),
      ),
    );
  }
}
