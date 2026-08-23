import 'package:flutter/material.dart';

import '../../../core/calling/call_models.dart';
import '../../../core/database/app_database.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<CallLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('call_logs', orderBy: 'start_time DESC');
    final logs = maps.map((m) => CallLog.fromMap(m)).toList();

    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? const Center(
              child: Text(
                'No past call history found.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              itemCount: _logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isVideo =
                    log.callType == CallType.video ||
                    log.callType == CallType.groupVideo;
                final isMissed =
                    log.status == 'missed' || log.status == 'declined';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMissed
                        ? Colors.redAccent.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    child: Icon(
                      isVideo ? Icons.videocam : Icons.call,
                      color: isMissed ? Colors.redAccent : Colors.blueAccent,
                    ),
                  ),
                  title: Text(
                    log.callerName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMissed ? Colors.redAccent : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '${log.callType.name.toUpperCase()} • ${log.status.toUpperCase()} (${log.durationSeconds}s)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Text(
                    '${log.startTime.hour.toString().padLeft(2, '0')}:${log.startTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}
