import 'package:flutter/material.dart';

import '../../../core/auth/services/auth_service.dart';
import '../../../core/groups/group_models.dart';
import '../../../core/groups/group_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final GroupService _groupService = GroupService.instance;

  List<GroupPoll> _polls = [];
  List<GroupEvent> _events = [];
  List<GroupAnnouncement> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupSocialData();
  }

  Future<void> _loadGroupSocialData() async {
    final polls = await _groupService.getPolls(widget.conversationId);
    final events = await _groupService.getEvents(widget.conversationId);
    final announcements = await _groupService.getAnnouncements(
      widget.conversationId,
    );

    if (mounted) {
      setState(() {
        _polls = polls;
        _events = events;
        _announcements = announcements;
        _isLoading = false;
      });
    }
  }

  Future<void> _createPollModal() async {
    final qController = TextEditingController();
    final opt1Controller = TextEditingController();
    final opt2Controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group Poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qController,
                decoration: const InputDecoration(
                  labelText: 'Poll Question',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: opt1Controller,
                decoration: const InputDecoration(
                  labelText: 'Option 1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: opt2Controller,
                decoration: const InputDecoration(
                  labelText: 'Option 2',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Poll'),
          ),
        ],
      ),
    );

    if (confirm == true &&
        qController.text.isNotEmpty &&
        opt1Controller.text.isNotEmpty &&
        opt2Controller.text.isNotEmpty) {
      await _groupService.createPoll(
        conversationId: widget.conversationId,
        question: qController.text,
        optionTexts: [opt1Controller.text, opt2Controller.text],
      );
      await _loadGroupSocialData();
    }
  }

  Future<void> _createEventModal() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Group Event'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Schedule'),
          ),
        ],
      ),
    );

    if (confirm == true && titleController.text.isNotEmpty) {
      final userId = AuthService.instance.currentUser?.id ?? 'local-user';
      await _groupService.createEvent(
        conversationId: widget.conversationId,
        title: titleController.text,
        description: descController.text,
        eventDate: DateTime.now().add(const Duration(days: 1)),
        creatorId: userId,
      );
      await _loadGroupSocialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Social & Features'),
        actions: [
          IconButton(icon: const Icon(Icons.poll), onPressed: _createPollModal),
          IconButton(
            icon: const Icon(Icons.event),
            onPressed: _createEventModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'GROUP ANNOUNCEMENTS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (_announcements.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No announcements yet.'),
                    ),
                  )
                else
                  ..._announcements.map(
                    (a) => Card(
                      color: Colors.amber.withValues(alpha: 0.15),
                      child: ListTile(
                        leading: const Icon(
                          Icons.campaign,
                          color: Colors.amberAccent,
                        ),
                        title: Text(
                          a.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${a.content}\nPosted by ${a.authorName}',
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'ACTIVE POLLS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (_polls.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No active group polls.'),
                    ),
                  )
                else
                  ..._polls.map(
                    (p) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.question,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...p.options.map(
                              (opt) => ListTile(
                                title: Text(opt.text),
                                trailing: Text('${opt.votes} votes'),
                                onTap: () async {
                                  final userId =
                                      AuthService.instance.currentUser?.id ??
                                      'local-user';
                                  await _groupService.voteInPoll(
                                    pollId: p.id,
                                    optionId: opt.id,
                                    userId: userId,
                                  );
                                  await _loadGroupSocialData();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'UPCOMING EVENTS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (_events.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No upcoming events.'),
                    ),
                  )
                else
                  ..._events.map(
                    (e) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.event_available,
                          color: Colors.greenAccent,
                        ),
                        title: Text(e.title),
                        subtitle: Text(
                          '${e.description ?? ''}\nScheduled for: ${e.eventDate.toLocal().toString().split('.')[0]}',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
