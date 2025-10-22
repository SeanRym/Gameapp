import 'dart:convert';
import '../models/auth_user.dart';
import '../database/database_helper.dart';
import 'game_library_service.dart';

class AuthService {
  static const String _usersKey = 'registered_users';
  static const String _currentUserKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _presencePrefix = 'user_online_';

  // Register a new user
  static Future<AuthResult> register(SignUpCredentials credentials) async {
    try {
      // Validate input
      final validationResult = _validateSignUp(credentials);
      if (!validationResult.isSuccess) {
        return validationResult;
      }

      // Check if user already exists
      final existingUsers = await _getAllUsers();
      
      // Check username availability
      if (existingUsers.any((user) => user.username.toLowerCase() == credentials.username.toLowerCase())) {
        return AuthResult(
          isSuccess: false,
          message: 'Username already exists',
        );
      }

      // Check email availability
      if (existingUsers.any((user) => user.email.toLowerCase() == credentials.email.toLowerCase())) {
        return AuthResult(
          isSuccess: false,
          message: 'Email already registered',
        );
      }

      // Create new user
      final newUser = AuthUser(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: credentials.username.trim(),
        email: credentials.email.trim().toLowerCase(),
        password: credentials.password, // In production, hash this password
        createdAt: DateTime.now(),
      );

      // Save user to database
      final db = await DatabaseHelper.database;
      await db.insert(DatabaseHelper.usersTable, {
        'id': newUser.id,
        'username': newUser.username,
        'email': newUser.email,
        'password': newUser.password,
        'created_at': newUser.createdAt.millisecondsSinceEpoch,
      });
      
      // Also update the in-memory list for compatibility
      existingUsers.add(newUser);
      await _saveAllUsers(existingUsers);

      // Clear any existing user data to ensure new account starts fresh
      await GameLibraryService.clearAllUserData();

      return AuthResult(
        isSuccess: true,
        message: 'Account created successfully',
        user: newUser,
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        message: 'Registration failed: ${e.toString()}',
      );
    }
  }

  // Login user
  static Future<AuthResult> login(LoginCredentials credentials) async {
    try {
      // Validate input
      if (credentials.usernameOrEmail.isEmpty || credentials.password.isEmpty) {
        return AuthResult(
          isSuccess: false,
          message: 'Please fill in all fields',
        );
      }

      // Get all users
      final users = await _getAllUsers();
      
      // Find user by username or email
      final user = users.firstWhere(
        (u) => u.username.toLowerCase() == credentials.usernameOrEmail.toLowerCase() ||
               u.email.toLowerCase() == credentials.usernameOrEmail.toLowerCase(),
        orElse: () => throw Exception('User not found'),
      );

      // Check password
      if (user.password != credentials.password) {
        return AuthResult(
          isSuccess: false,
          message: 'Invalid password',
        );
      }

      // Save login state
      await _setCurrentUser(user);
      await _setLoggedInState(true);
      await _setPresence(user.id, true);
      
      // Store current user ID for GameLibraryService
      await DatabaseHelper.setAppState('current_user_id', user.id);
      print('DEBUG: Stored current user ID: ${user.id}');

      return AuthResult(
        isSuccess: true,
        message: 'Login successful',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        message: 'Invalid username/email or password',
      );
    }
  }

  // Logout user
  static Future<void> logout() async {
    final me = await getCurrentUser();
    if (me != null) {
      await _setPresence(me.id, false);
    }
    await _setCurrentUser(null);
    await _setLoggedInState(false);
    
    // Clear current user ID
    await DatabaseHelper.removeAppState('current_user_id');
    print('DEBUG: Cleared current user ID');
    
    // Don't clear user data on logout - only clear on new account creation
    // This ensures library and friends persist between login sessions
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final isLoggedInStr = await DatabaseHelper.getAppState(_isLoggedInKey);
    return isLoggedInStr == 'true';
  }

  // Get current user
  static Future<AuthUser?> getCurrentUser() async {
    final userJson = await DatabaseHelper.getAppState(_currentUserKey);
    if (userJson != null) {
      return AuthUser.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  // Validate sign up credentials
  static AuthResult _validateSignUp(SignUpCredentials credentials) {
    // Username validation
    if (credentials.username.isEmpty) {
      return AuthResult(isSuccess: false, message: 'Username is required');
    }
    if (credentials.username.length < 3) {
      return AuthResult(isSuccess: false, message: 'Username must be at least 3 characters');
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(credentials.username)) {
      return AuthResult(isSuccess: false, message: 'Username can only contain letters, numbers, and underscores');
    }

    // Email validation
    if (credentials.email.isEmpty) {
      return AuthResult(isSuccess: false, message: 'Email is required');
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(credentials.email)) {
      return AuthResult(isSuccess: false, message: 'Please enter a valid email address');
    }

    // Password validation
    if (credentials.password.isEmpty) {
      return AuthResult(isSuccess: false, message: 'Password is required');
    }
    if (credentials.password.length < 6) {
      return AuthResult(isSuccess: false, message: 'Password must be at least 6 characters');
    }

    // Confirm password validation
    if (credentials.password != credentials.confirmPassword) {
      return AuthResult(isSuccess: false, message: 'Passwords do not match');
    }

    return AuthResult(isSuccess: true, message: 'Validation successful');
  }

  // Initialize demo user account
  static Future<void> initializeDemoUser() async {
    final existingUsers = await _getAllUsers();
    
    // Check if demo user already exists
    if (existingUsers.any((user) => user.username.toLowerCase() == 'demo')) {
      return;
    }

    // Create demo user
    final demoUser = AuthUser(
      id: 'demo_user',
      username: 'demo',
      email: 'demo@example.com',
      password: 'demo123',
      createdAt: DateTime.now(),
    );

    // Save demo user to database
    final db = await DatabaseHelper.database;
    await db.insert(DatabaseHelper.usersTable, {
      'id': demoUser.id,
      'username': demoUser.username,
      'email': demoUser.email,
      'password': demoUser.password,
      'created_at': demoUser.createdAt.millisecondsSinceEpoch,
    });
    
    // Also update the in-memory list for compatibility
    existingUsers.add(demoUser);
    await _saveAllUsers(existingUsers);
  }

  // Get all registered users (public method for friend validation)
  static Future<List<AuthUser>> getAllUsers() async {
    return await _getAllUsers();
  }

  // Helper methods
  static Future<List<AuthUser>> _getAllUsers() async {
    final db = await DatabaseHelper.database;
    final result = await db.query(DatabaseHelper.usersTable);
    return result.map((row) => AuthUser(
      id: row['id'] as String,
      username: row['username'] as String,
      email: row['email'] as String,
      password: row['password'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    )).toList();
  }

  static Future<void> _saveAllUsers(List<AuthUser> users) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      // Clear existing users
      await txn.delete(DatabaseHelper.usersTable);
      // Insert all users
      for (final user in users) {
        await txn.insert(DatabaseHelper.usersTable, {
          'id': user.id,
          'username': user.username,
          'email': user.email,
          'password': user.password,
          'created_at': user.createdAt.millisecondsSinceEpoch,
        });
      }
    });
  }

  static Future<void> _setCurrentUser(AuthUser? user) async {
    if (user != null) {
      await DatabaseHelper.setAppState(_currentUserKey, jsonEncode(user.toJson()));
    } else {
      await DatabaseHelper.removeAppState(_currentUserKey);
    }
  }

  static Future<void> _setLoggedInState(bool isLoggedIn) async {
    await DatabaseHelper.setAppState(_isLoggedInKey, isLoggedIn.toString());
  }

  // Presence helpers
  static Future<void> _setPresence(String userId, bool online) async {
    final db = await DatabaseHelper.database;
    await db.update(
      DatabaseHelper.usersTable,
      {
        'is_online': online ? 1 : 0,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  static Future<bool> isUserOnline(String userId) async {
    final db = await DatabaseHelper.database;
    final result = await db.query(
      DatabaseHelper.usersTable,
      columns: ['is_online'],
      where: 'id = ?',
      whereArgs: [userId],
    );
    return result.isNotEmpty && (result.first['is_online'] as int) == 1;
  }
}

class AuthResult {
  final bool isSuccess;
  final String message;
  final AuthUser? user;

  AuthResult({
    required this.isSuccess,
    required this.message,
    this.user,
  });
}
