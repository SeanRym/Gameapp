import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _databaseName = 'salas_app.db';
  static const int _databaseVersion = 2;

  // Table names
  static const String usersTable = 'users';
  static const String userProfilesTable = 'user_profiles';
  static const String gamesTable = 'games';
  static const String userLibraryTable = 'user_library';
  static const String achievementsTable = 'achievements';
  static const String userAchievementsTable = 'user_achievements';
  static const String friendshipsTable = 'friendships';
  static const String friendRequestsTable = 'friend_requests';
  static const String gameReviewsTable = 'game_reviews';
  static const String gameInvitesTable = 'game_invites';
  static const String sessionInvitesTable = 'session_invites';
  static const String messagesTable = 'messages';
  static const String sessionChatMessagesTable = 'session_chat_messages';
  static const String appStateTable = 'app_state'; // For current user, login state, etc.

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE $usersTable (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_login INTEGER,
        is_online INTEGER DEFAULT 0,
        last_seen INTEGER
      )
    ''');

    // User profiles table
    await db.execute('''
      CREATE TABLE $userProfilesTable (
        user_id TEXT PRIMARY KEY,
        display_name TEXT,
        bio TEXT,
        avatar_url TEXT,
        level INTEGER DEFAULT 1,
        total_playtime INTEGER DEFAULT 0,
        games_owned INTEGER DEFAULT 0,
        achievements_unlocked INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES $usersTable (id) ON DELETE CASCADE
      )
    ''');

    // Games table
    await db.execute('''
      CREATE TABLE $gamesTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        price REAL,
        tags TEXT,
        popularity REAL DEFAULT 0,
        release_date INTEGER,
        developer TEXT,
        publisher TEXT
      )
    ''');

    // User library table
    await db.execute('''
      CREATE TABLE $userLibraryTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        game_id TEXT NOT NULL,
        title TEXT NOT NULL,
        image_url TEXT,
        purchase_date INTEGER NOT NULL,
        price_paid REAL NOT NULL,
        playtime_hours INTEGER DEFAULT 0,
        last_played INTEGER,
        is_installed INTEGER DEFAULT 0,
        version TEXT DEFAULT '1.0.0',
        user_rating REAL DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        achievements TEXT DEFAULT '[]',
        FOREIGN KEY (user_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        UNIQUE(user_id, game_id)
      )
    ''');

    // Achievements table
    await db.execute('''
      CREATE TABLE $achievementsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        icon_url TEXT,
        category TEXT,
        points INTEGER DEFAULT 0
      )
    ''');

    // User achievements table
    await db.execute('''
      CREATE TABLE $userAchievementsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        achievement_id TEXT NOT NULL,
        unlocked_at INTEGER NOT NULL,
        progress INTEGER DEFAULT 100,
        is_unlocked INTEGER DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        FOREIGN KEY (achievement_id) REFERENCES $achievementsTable (id) ON DELETE CASCADE,
        UNIQUE(user_id, achievement_id)
      )
    ''');

    // Friendships table
    await db.execute('''
      CREATE TABLE $friendshipsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user1_id TEXT NOT NULL,
        user2_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user1_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        FOREIGN KEY (user2_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        UNIQUE(user1_id, user2_id),
        CHECK (user1_id < user2_id)
      )
    ''');

    // Friend requests table
    await db.execute('''
      CREATE TABLE $friendRequestsTable (
        id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        from_username TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        to_username TEXT NOT NULL,
        sent_at INTEGER NOT NULL,
        status TEXT DEFAULT 'pending',
        FOREIGN KEY (from_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        FOREIGN KEY (to_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE
      )
    ''');

    // Game reviews table
    await db.execute('''
      CREATE TABLE $gameReviewsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        game_id TEXT NOT NULL,
        rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
        review_text TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        FOREIGN KEY (game_id) REFERENCES $gamesTable (id) ON DELETE CASCADE,
        UNIQUE(user_id, game_id)
      )
    ''');

    // Game invites table
    await db.execute('''
      CREATE TABLE $gameInvitesTable (
        id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        from_username TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        game_id TEXT NOT NULL,
        game_title TEXT NOT NULL,
        sent_at INTEGER NOT NULL,
        read INTEGER DEFAULT 0,
        FOREIGN KEY (from_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        FOREIGN KEY (to_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE
      )
    ''');

    // Session invites table
    await db.execute('''
      CREATE TABLE $sessionInvitesTable (
        id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        from_username TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        session_title TEXT NOT NULL,
        game_title TEXT NOT NULL,
        sent_at INTEGER NOT NULL,
        read INTEGER DEFAULT 0,
        FOREIGN KEY (from_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        FOREIGN KEY (to_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE $messagesTable (
        id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        text TEXT NOT NULL,
        sent_at INTEGER NOT NULL,
        read INTEGER DEFAULT 0,
        FOREIGN KEY (from_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
        FOREIGN KEY (to_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE
      )
    ''');

    // Session chat messages table
    await db.execute('''
      CREATE TABLE $sessionChatMessagesTable (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        from_user_id TEXT NOT NULL,
        from_username TEXT NOT NULL,
        text TEXT NOT NULL,
        sent_at INTEGER NOT NULL,
        FOREIGN KEY (from_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE
      )
    ''');

    // App state table (for current user, login state, etc.)
    await db.execute('''
      CREATE TABLE $appStateTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_user_library_user_id ON $userLibraryTable(user_id)');
    await db.execute('CREATE INDEX idx_user_achievements_user_id ON $userAchievementsTable(user_id)');
    await db.execute('CREATE INDEX idx_friendships_user1 ON $friendshipsTable(user1_id)');
    await db.execute('CREATE INDEX idx_friendships_user2 ON $friendshipsTable(user2_id)');
    await db.execute('CREATE INDEX idx_friend_requests_to_user ON $friendRequestsTable(to_user_id)');
    await db.execute('CREATE INDEX idx_game_reviews_game_id ON $gameReviewsTable(game_id)');
    await db.execute('CREATE INDEX idx_game_invites_to_user ON $gameInvitesTable(to_user_id)');
    await db.execute('CREATE INDEX idx_messages_to_user ON $messagesTable(to_user_id)');
    await db.execute('CREATE INDEX idx_messages_from_user ON $messagesTable(from_user_id)');
    await db.execute('CREATE INDEX idx_session_chat_session_id ON $sessionChatMessagesTable(session_id)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add session invites table for version 2
      await db.execute('''
        CREATE TABLE $sessionInvitesTable (
          id TEXT PRIMARY KEY,
          from_user_id TEXT NOT NULL,
          from_username TEXT NOT NULL,
          to_user_id TEXT NOT NULL,
          session_id TEXT NOT NULL,
          session_title TEXT NOT NULL,
          game_title TEXT NOT NULL,
          sent_at INTEGER NOT NULL,
          read INTEGER DEFAULT 0,
          FOREIGN KEY (from_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE,
          FOREIGN KEY (to_user_id) REFERENCES $usersTable (id) ON DELETE CASCADE
        )
      ''');
      
      // Add index for session invites
      await db.execute('CREATE INDEX idx_session_invites_to_user ON $sessionInvitesTable(to_user_id)');
    }
  }

  // Helper methods for app state (replaces SharedPreferences for simple values)
  static Future<void> setAppState(String key, String value) async {
    final db = await database;
    await db.insert(
      appStateTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getAppState(String key) async {
    final db = await database;
    final result = await db.query(
      appStateTable,
      where: 'key = ?',
      whereArgs: [key],
    );
    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  static Future<void> removeAppState(String key) async {
    final db = await database;
    await db.delete(
      appStateTable,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // Helper method to check if we need to migrate from SharedPreferences
  static Future<bool> needsMigration() async {
    final db = await database;
    final result = await db.query(appStateTable, where: 'key = ?', whereArgs: ['migrated_from_shared_prefs']);
    return result.isEmpty;
  }

  // Mark migration as complete
  static Future<void> markMigrationComplete() async {
    await setAppState('migrated_from_shared_prefs', 'true');
  }

  // Close database
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // Clear database (for development/testing)
  static Future<void> clearDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
    
    // Delete the database file
    String path = join(await getDatabasesPath(), _databaseName);
    await databaseFactory.deleteDatabase(path);
    
    // Recreate database
    _database = await _initDatabase();
  }
}
