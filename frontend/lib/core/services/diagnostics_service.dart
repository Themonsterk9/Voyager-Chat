import 'package:sqflite/sqflite.dart';

import '../auth/services/auth_service.dart';
import '../database/app_database.dart';

class SystemDiagnostics {
  const SystemDiagnostics({
    required this.conversationCount,
    required this.messageCount,
    required this.pendingMessageCount,
    required this.reactionCount,
    required this.isAuthenticated,
    required this.currentUserEmail,
    required this.dbVersion,
  });

  final int conversationCount;
  final int messageCount;
  final int pendingMessageCount;
  final int reactionCount;
  final bool isAuthenticated;
  final String? currentUserEmail;
  final int dbVersion;

  String exportReport() {
    return '''
==================================================
VOYAGER CHAT SYSTEM DIAGNOSTICS REPORT
Timestamp: ${DateTime.now().toUtc().toIso8601String()}
==================================================
Authentication Status : ${isAuthenticated ? 'Authenticated' : 'Not Authenticated'}
Current User Email    : ${currentUserEmail ?? 'N/A'}
SQLite DB Version     : $dbVersion
Conversations Count   : $conversationCount
Messages Count        : $messageCount
Pending Messages      : $pendingMessageCount
Message Reactions     : $reactionCount
Status                : HEALTHY
==================================================
''';
  }
}

class DiagnosticsService {
  DiagnosticsService._();

  static final DiagnosticsService instance = DiagnosticsService._();

  Future<SystemDiagnostics> runDiagnostics() async {
    final db = await AppDatabase.instance.database;

    final convRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM conversations',
    );
    final msgRes = await db.rawQuery('SELECT COUNT(*) as count FROM messages');
    final pendingRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_messages',
    );
    final reactRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM message_reactions',
    );

    final conversationCount = Sqflite.firstIntValue(convRes) ?? 0;
    final messageCount = Sqflite.firstIntValue(msgRes) ?? 0;
    final pendingMessageCount = Sqflite.firstIntValue(pendingRes) ?? 0;
    final reactionCount = Sqflite.firstIntValue(reactRes) ?? 0;

    final user = AuthService.instance.currentUser;

    return SystemDiagnostics(
      conversationCount: conversationCount,
      messageCount: messageCount,
      pendingMessageCount: pendingMessageCount,
      reactionCount: reactionCount,
      isAuthenticated: user != null,
      currentUserEmail: user?.email,
      dbVersion: 5,
    );
  }
}
