import 'package:flutter/material.dart';

import '../../../core/meetings/meeting_models.dart';
import '../../../core/meetings/meeting_service.dart';

class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({super.key, required this.meetingId});

  final String meetingId;

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  final MeetingService _meetingService = MeetingService.instance;

  bool _isScreenSharing = false;
  bool _isHandRaised = false;

  @override
  Widget build(BuildContext context) {
    final participants = _meetingService.getParticipants(widget.meetingId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Collaboration Meeting',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isHandRaised ? Icons.front_hand : Icons.pan_tool_outlined,
              color: _isHandRaised ? Colors.amberAccent : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isHandRaised = !_isHandRaised;
              });
              _meetingService.toggleHandRaise(widget.meetingId, 'local-user');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isScreenSharing)
            Container(
              height: 180,
              margin: const EdgeInsets.all(12),
              color: Colors.blueGrey.shade900,
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.screen_share,
                      color: Colors.greenAccent,
                      size: 36,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Screen Share Active (Display 1)',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: participants.isEmpty ? 1 : participants.length,
              itemBuilder: (context, index) {
                final p = participants.isEmpty
                    ? const MeetingParticipant(
                        userId: 'local-user',
                        displayName: 'Local Voyager User',
                        isAdmitted: true,
                      )
                    : participants[index];

                return Card(
                  color: Colors.grey.shade900,
                  child: Stack(
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.blueAccent,
                          child: Text(
                            p.displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Row(
                          children: [
                            Text(
                              p.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            if (p.isHandRaised)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.front_hand,
                                  color: Colors.amberAccent,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Host Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.grey.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(
                    _isScreenSharing
                        ? Icons.stop_screen_share
                        : Icons.screen_share,
                    color: _isScreenSharing
                        ? Colors.redAccent
                        : Colors.greenAccent,
                  ),
                  onPressed: () {
                    setState(() {
                      _isScreenSharing = !_isScreenSharing;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.redAccent),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
