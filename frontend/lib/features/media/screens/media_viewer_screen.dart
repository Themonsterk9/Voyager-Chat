import 'package:flutter/material.dart';

import '../../../core/media/media_models.dart';

class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({super.key, required this.attachment});

  final MediaAttachment attachment;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.attachment.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Downloading encrypted attachment...'),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(child: _buildMediaBody()),
    );
  }

  Widget _buildMediaBody() {
    switch (widget.attachment.type) {
      case AttachmentType.image:
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Icon(Icons.image, size: 120, color: Colors.blueAccent),
            ),
          ),
        );
      case AttachmentType.video:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 240,
              color: Colors.grey.shade900,
              child: Center(
                child: IconButton(
                  iconSize: 64,
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Duration: ${widget.attachment.durationSeconds}s',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        );
      case AttachmentType.audio:
        return Card(
          margin: const EdgeInsets.all(24),
          color: Colors.grey.shade900,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.audiotrack,
                  size: 64,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.attachment.fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPlaying = !_isPlaying;
                        });
                      },
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _isPlaying ? 0.45 : 0.0,
                        backgroundColor: Colors.grey,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case AttachmentType.document:
        return Card(
          margin: const EdgeInsets.all(24),
          color: Colors.grey.shade900,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.insert_drive_file,
                  size: 64,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.attachment.fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(widget.attachment.fileSize / 1024).toStringAsFixed(1)} KB • E2EE Encrypted',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
    }
  }
}
