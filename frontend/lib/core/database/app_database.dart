import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _databaseName = 'voyager_chat.db';
  static const int _databaseVersion = 17;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();

    return _database!;
  }

  Future<Database> _openDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasesPath = await getDatabasesPath();

    final path = join(databasesPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT,
        pinned_at TEXT,
        archived_at TEXT,
        avatar_url TEXT,
        invite_code TEXT,
        draft_text TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE conversation_members (
        conversation_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        joined_at TEXT,
        last_read_at TEXT,
        role TEXT DEFAULT 'member',
        is_muted INTEGER DEFAULT 0,
        PRIMARY KEY (conversation_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT,
        message_type TEXT NOT NULL,
        client_message_id TEXT,
        created_at TEXT,
        edited_at TEXT,
        deleted_at TEXT,
        reply_to_message_id TEXT,
        scheduled_at TEXT,
        delivery_state TEXT DEFAULT 'SERVER_DELIVERED',
        transport_type TEXT DEFAULT 'internet',
        is_encrypted INTEGER DEFAULT 1,
        cipher_payload TEXT,
        location_lat REAL,
        location_lng REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE message_status (
        message_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        delivered_at TEXT,
        read_at TEXT,
        PRIMARY KEY (message_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE message_reactions (
        id TEXT PRIMARY KEY,
        message_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        emoji TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE blocks (
        id TEXT PRIMARY KEY,
        blocker_id TEXT NOT NULL,
        blocked_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        reporter_id TEXT NOT NULL,
        reported_id TEXT NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE nearby_peers (
        device_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        rssi INTEGER DEFAULT -60,
        last_seen TEXT NOT NULL,
        is_trusted INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE device_keys (
        device_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        public_key TEXT NOT NULL,
        fingerprint TEXT NOT NULL,
        is_verified INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE shared_locations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL DEFAULT 10.0,
        expires_at TEXT NOT NULL,
        is_live INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE call_logs (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        caller_id TEXT NOT NULL,
        caller_name TEXT NOT NULL,
        call_type TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        duration_seconds INTEGER DEFAULT 0,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notification_preferences (
        conversation_id TEXT PRIMARY KEY,
        is_muted INTEGER DEFAULT 0,
        muted_until TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recent_searches (
        id TEXT PRIMARY KEY,
        query_text TEXT NOT NULL,
        searched_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE group_polls (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        question TEXT NOT NULL,
        options_json TEXT NOT NULL,
        voters_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE group_events (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        event_date TEXT NOT NULL,
        location_name TEXT,
        creator_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE group_announcements (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        author_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE message_attachments (
        id TEXT PRIMARY KEY,
        message_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        mime_type TEXT NOT NULL,
        storage_url TEXT,
        local_path TEXT,
        duration_seconds INTEGER DEFAULT 0,
        thumbnail_url TEXT,
        is_encrypted INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE meetings (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        host_id TEXT NOT NULL,
        scheduled_time TEXT NOT NULL,
        started_at TEXT,
        ended_at TEXT,
        status TEXT NOT NULL,
        participant_limit INTEGER DEFAULT 25
      )
    ''');

    await db.execute('''
      CREATE TABLE meeting_participants (
        meeting_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT DEFAULT 'participant',
        joined_at TEXT NOT NULL,
        is_admitted INTEGER DEFAULT 0,
        PRIMARY KEY (meeting_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        user_id TEXT NOT NULL,
        details_json TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        prev_hash TEXT NOT NULL,
        hash TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE retention_policies (
        conversation_id TEXT PRIMARY KEY,
        retention_days INTEGER DEFAULT 30,
        auto_delete_ephemeral INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_conversation
      ON messages(conversation_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_created_at
      ON messages(created_at)
    ''');

    await _createPendingMessagesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPendingMessagesTable(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE messages ADD COLUMN reply_to_message_id TEXT',
        );
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE conversations ADD COLUMN pinned_at TEXT');
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE conversations ADD COLUMN archived_at TEXT',
        );
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS message_reactions (
          id TEXT PRIMARY KEY,
          message_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          emoji TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS blocks (
          id TEXT PRIMARY KEY,
          blocker_id TEXT NOT NULL,
          blocked_id TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reports (
          id TEXT PRIMARY KEY,
          reporter_id TEXT NOT NULL,
          reported_id TEXT NOT NULL,
          reason TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE conversations ADD COLUMN avatar_url TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE conversations ADD COLUMN invite_code TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE conversation_members ADD COLUMN role TEXT DEFAULT 'member'",
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE conversation_members ADD COLUMN is_muted INTEGER DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE conversations ADD COLUMN draft_text TEXT',
        );
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN scheduled_at TEXT');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          "ALTER TABLE messages ADD COLUMN delivery_state TEXT DEFAULT 'SERVER_DELIVERED'",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE messages ADD COLUMN transport_type TEXT DEFAULT 'internet'",
        );
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS nearby_peers (
          device_id TEXT PRIMARY KEY,
          display_name TEXT NOT NULL,
          rssi INTEGER DEFAULT -60,
          last_seen TEXT NOT NULL,
          is_trusted INTEGER DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE messages ADD COLUMN is_encrypted INTEGER DEFAULT 1',
        );
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN cipher_payload TEXT');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS device_keys (
          device_id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          public_key TEXT NOT NULL,
          fingerprint TEXT NOT NULL,
          is_verified INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN location_lat REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN location_lng REAL');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shared_locations (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          accuracy REAL DEFAULT 10.0,
          expires_at TEXT NOT NULL,
          is_live INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS call_logs (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          caller_id TEXT NOT NULL,
          caller_name TEXT NOT NULL,
          call_type TEXT NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT,
          duration_seconds INTEGER DEFAULT 0,
          status TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notification_preferences (
          conversation_id TEXT PRIMARY KEY,
          is_muted INTEGER DEFAULT 0,
          muted_until TEXT
        )
      ''');
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recent_searches (
          id TEXT PRIMARY KEY,
          query_text TEXT NOT NULL,
          searched_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_polls (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          question TEXT NOT NULL,
          options_json TEXT NOT NULL,
          voters_json TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_events (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          event_date TEXT NOT NULL,
          location_name TEXT,
          creator_id TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_announcements (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          author_name TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS message_attachments (
          id TEXT PRIMARY KEY,
          message_id TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          mime_type TEXT NOT NULL,
          storage_url TEXT,
          local_path TEXT,
          duration_seconds INTEGER DEFAULT 0,
          thumbnail_url TEXT,
          is_encrypted INTEGER DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meetings (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          host_id TEXT NOT NULL,
          scheduled_time TEXT NOT NULL,
          started_at TEXT,
          ended_at TEXT,
          status TEXT NOT NULL,
          participant_limit INTEGER DEFAULT 25
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS meeting_participants (
          meeting_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          role TEXT DEFAULT 'participant',
          joined_at TEXT NOT NULL,
          is_admitted INTEGER DEFAULT 0,
          PRIMARY KEY (meeting_id, user_id)
        )
      ''');
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id TEXT PRIMARY KEY,
          event_type TEXT NOT NULL,
          user_id TEXT NOT NULL,
          details_json TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          prev_hash TEXT NOT NULL,
          hash TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS retention_policies (
          conversation_id TEXT PRIMARY KEY,
          retention_days INTEGER DEFAULT 30,
          auto_delete_ephemeral INTEGER DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profiles (
          id TEXT PRIMARY KEY,
          username TEXT,
          display_name TEXT,
          avatar_url TEXT,
          email TEXT,
          auth_provider TEXT,
          status TEXT DEFAULT 'offline',
          last_seen TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    }
  }

  Future<void> _createPendingMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT,
        message_type TEXT NOT NULL,
        client_message_id TEXT,
        created_at TEXT NOT NULL,
        queued_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_messages_created_at
      ON pending_messages(created_at)
    ''');
  }

  Future<void> close() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
