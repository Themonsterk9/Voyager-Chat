import 'package:flutter/material.dart';

import '../../../core/media/media_models.dart';
import 'media_viewer_screen.dart';

class MediaGalleryScreen extends StatefulWidget {
  const MediaGalleryScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  final List<MediaAttachment> _attachments = [
    const MediaAttachment(
      id: 'att-1',
      messageId: 'msg-1',
      fileName: 'architecture_diagram.png',
      fileSize: 1048576,
      mimeType: 'image/png',
    ),
    const MediaAttachment(
      id: 'att-2',
      messageId: 'msg-2',
      fileName: 'keynote_presentation.mp4',
      fileSize: 5242880,
      mimeType: 'video/mp4',
      durationSeconds: 120,
    ),
    const MediaAttachment(
      id: 'att-3',
      messageId: 'msg-3',
      fileName: 'voice_memo_001.m4a',
      fileSize: 512000,
      mimeType: 'audio/m4a',
      durationSeconds: 45,
    ),
    const MediaAttachment(
      id: 'att-4',
      messageId: 'msg-4',
      fileName: 'project_specification.pdf',
      fileSize: 2097152,
      mimeType: 'application/pdf',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media & Shared Files')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _attachments.length,
        itemBuilder: (context, index) {
          final item = _attachments[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MediaViewerScreen(attachment: item),
                ),
              );
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.grey.shade900,
                    child: Center(
                      child: Icon(
                        item.type == AttachmentType.image
                            ? Icons.image
                            : (item.type == AttachmentType.video
                                  ? Icons.videocam
                                  : (item.type == AttachmentType.audio
                                        ? Icons.audiotrack
                                        : Icons.insert_drive_file)),
                        size: 48,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        item.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
