import 'package:flutter/material.dart';

class NotificationBannerService {
  NotificationBannerService._();

  static final NotificationBannerService instance =
      NotificationBannerService._();

  void showNotificationBanner(
    BuildContext context, {
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: Colors.grey.shade900,
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.blueAccent,
          onPressed: onTap,
        ),
      ),
    );
  }
}
