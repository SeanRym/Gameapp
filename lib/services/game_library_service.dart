import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_data.dart';
import '../models/auth_user.dart';
import '../data.dart';
import '../database/database_helper.dart';
import 'auth_service.dart';

class GameLibraryService {
  static const String _libraryKey = 'user_library_';
  static const String _profileKey = 'user_profile_';
  static const String _achievementsKey = 'user_achievements_';
  static const String _friendsKey = 'user_friends_';
  static const String _inboxKey = 'user_inbox_'; // per-user message threads
  static const String _invitesKey = 'user_invites_'; // per-user game invites
  static const String _sessionChatKey = 'session_chat_'; // per-session group chat

  // Get user profile
  static Future<UserProfile?> getUserProfile() async {
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return null;
    
    final db = await DatabaseHelper.database;
    final result = await db.query(
      DatabaseHelper.userProfilesTable,
      where: 'user_id = ?',
      whereArgs: [currentUser],
    );
    
    if (result.isNotEmpty) {
      final row = result.first;
      return UserProfile(
        id: currentUser,
        username: '', // Will be filled from AuthService if needed
        email: '', // Will be filled from AuthService if needed
        avatarUrl: row['avatar_url'] as String? ?? '',
        level: row['level'] as int? ?? 1,
        xp: 0, // Default XP
        country: '', // Default country
        joinDate: DateTime.now(), // Default join date
        ownedGames: [], // Will be populated from library
        wishlist: [], // Default empty wishlist
        friends: [], // Will be populated from friends table
        achievements: [], // Will be populated from achievements table
        gamePlaytime: {}, // Will be populated from library
        gameRatings: {}, // Will be populated from library
      );
    }
    return null;
  }

  // Save user profile
  static Future<void> saveUserProfile(UserProfile profile) async {
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    final db = await DatabaseHelper.database;
    await db.insert(
      DatabaseHelper.userProfilesTable,
      {
        'user_id': currentUser,
        'display_name': profile.username,
        'bio': '',
        'avatar_url': profile.avatarUrl,
        'level': profile.level,
        'total_playtime': 0, // Will be calculated from library
        'games_owned': profile.ownedGames.length,
        'achievements_unlocked': profile.achievements.length,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get user's game library
  static Future<List<LibraryGame>> getUserLibrary() async {
    final currentUser = await _getCurrentUserId();
    print('DEBUG: Getting library for user: $currentUser');
    if (currentUser == null) {
      print('DEBUG: No current user found');
      return [];
    }
    
    final db = await DatabaseHelper.database;
    final result = await db.query(
      DatabaseHelper.userLibraryTable,
      where: 'user_id = ?',
      whereArgs: [currentUser],
    );
    
    final games = result.map((row) => LibraryGame(
      gameId: row['game_id'] as String,
      title: row['title'] as String,
      imageUrl: row['image_url'] as String? ?? '',
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(row['purchase_date'] as int),
      pricePaid: row['price_paid'] as double,
      playtimeHours: row['playtime_hours'] as int,
      lastPlayed: row['last_played'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(row['last_played'] as int)
          : null,
      isInstalled: (row['is_installed'] as int) == 1,
      version: row['version'] as String,
      achievements: [], // Will be populated from achievements table
      userRating: row['user_rating'] as double,
      isFavorite: (row['is_favorite'] as int) == 1,
    )).toList();
    
    print('DEBUG: Found ${games.length} games in library');
    return games;
  }

  // Add game to library
  static Future<void> addGameToLibrary(String gameId, double pricePaid) async {
    print('DEBUG: Adding game $gameId to library with price $pricePaid');
    
    // Check if user is logged in
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      print('DEBUG: User is not logged in, cannot add game to library');
      throw Exception('User must be logged in to add games to library');
    }
    
    // Search in all game lists
    GameItem? game;
    
    try {
      game = mockGames.firstWhere((g) => g.id == gameId);
      print('DEBUG: Found game in mockGames: ${game.title}');
    } catch (e) {
      try {
        game = mostPlayedGames.firstWhere((g) => g.id == gameId);
        print('DEBUG: Found game in mostPlayedGames: ${game.title}');
      } catch (e) {
        try {
          game = topSellersGames.firstWhere((g) => g.id == gameId);
          print('DEBUG: Found game in topSellersGames: ${game.title}');
        } catch (e) {
          try {
            game = vrGames.firstWhere((g) => g.id == gameId);
            print('DEBUG: Found game in vrGames: ${game.title}');
          } catch (e) {
            print('DEBUG: Game with ID $gameId not found in any game list');
            throw Exception('Game with ID $gameId not found in any game list');
          }
        }
      }
    }
    
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) {
      print('DEBUG: No current user, cannot add game to library');
      return;
    }
    
    final db = await DatabaseHelper.database;
    await db.insert(
      DatabaseHelper.userLibraryTable,
      {
        'user_id': currentUser,
        'game_id': gameId,
        'title': game.title,
        'image_url': game.imageUrl,
        'purchase_date': DateTime.now().millisecondsSinceEpoch,
        'price_paid': pricePaid,
        'playtime_hours': 0,
        'is_installed': 0,
        'version': '1.0.0',
        'achievements': '[]',
        'user_rating': 0.0,
        'is_favorite': 0,
      },
    );
    
    print('DEBUG: Game added to library successfully');
  }

  // Remove game from library
  static Future<void> removeGameFromLibrary(String gameId) async {
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    final db = await DatabaseHelper.database;
    await db.delete(
      DatabaseHelper.userLibraryTable,
      where: 'user_id = ? AND game_id = ?',
      whereArgs: [currentUser, gameId],
    );
  }

  // Update game playtime
  static Future<void> updatePlaytime(String gameId, int hours) async {
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    final db = await DatabaseHelper.database;
    await db.update(
      DatabaseHelper.userLibraryTable,
      {
        'playtime_hours': hours,
        'last_played': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'user_id = ? AND game_id = ?',
      whereArgs: [currentUser, gameId],
    );
  }

  // Toggle favorite status
  static Future<void> toggleFavorite(String gameId) async {
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    final db = await DatabaseHelper.database;
    // First get current favorite status
    final result = await db.query(
      DatabaseHelper.userLibraryTable,
      columns: ['is_favorite'],
      where: 'user_id = ? AND game_id = ?',
      whereArgs: [currentUser, gameId],
    );
    
    if (result.isNotEmpty) {
      final currentFavorite = (result.first['is_favorite'] as int) == 1;
      await db.update(
        DatabaseHelper.userLibraryTable,
        {'is_favorite': currentFavorite ? 0 : 1},
        where: 'user_id = ? AND game_id = ?',
        whereArgs: [currentUser, gameId],
      );
    }
  }

  // Get game reviews
  static Future<List<GameReview>> getGameReviews(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get all reviews (global storage)
    final reviewsJson = prefs.getString('global_game_reviews');
    if (reviewsJson != null) {
      final List<dynamic> reviewsList = jsonDecode(reviewsJson);
      return reviewsList
          .map((json) => GameReview.fromJson(json))
          .where((review) => review.gameId == gameId)
          .toList();
    }
    return [];
  }

  // Add game review
  static Future<void> addGameReview(GameReview review) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get all reviews (global storage)
    final reviewsJson = prefs.getString('global_game_reviews');
    List<dynamic> reviewsList = [];
    
    if (reviewsJson != null) {
      reviewsList = jsonDecode(reviewsJson);
    }
    
    reviewsList.add(review.toJson());
    await prefs.setString('global_game_reviews', jsonEncode(reviewsList));
  }

  // Get user achievements
  static Future<List<UserAchievement>> getUserAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return [];
    
    final achievementsJson = prefs.getString('$_achievementsKey$currentUser');
    if (achievementsJson != null) {
      final List<dynamic> achievementsList = jsonDecode(achievementsJson);
      return achievementsList.map((json) => UserAchievement.fromJson(json)).toList();
    }
    return [];
  }

  // Unlock achievement
  static Future<void> unlockAchievement(String achievementId) async {
    final achievements = await getUserAchievements();
    final existingIndex = achievements.indexWhere((a) => a.achievementId == achievementId);
    
    if (existingIndex == -1) {
      achievements.add(UserAchievement(
        achievementId: achievementId,
        unlockedAt: DateTime.now(),
        progress: 100,
        isUnlocked: true,
      ));
      // Save achievements to database
      final currentUser = await _getCurrentUserId();
      if (currentUser != null) {
        final db = await DatabaseHelper.database;
        await db.insert(
          DatabaseHelper.userAchievementsTable,
          {
            'user_id': currentUser,
            'achievement_id': achievementId,
            'unlocked_at': DateTime.now().millisecondsSinceEpoch,
            'progress': 100,
            'is_unlocked': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  // Get friends list
  static Future<List<Friend>> getFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return [];
    
    final friendsJson = prefs.getString('$_friendsKey$currentUser');
    if (friendsJson != null) {
      final List<dynamic> friendsList = jsonDecode(friendsJson);
      final list = friendsList.map((json) => Friend.fromJson(json)).toList();
      // Update presence based on AuthService
      for (var i = 0; i < list.length; i++) {
        final f = list[i];
        final online = await AuthService.isUserOnline(f.id);
        list[i] = Friend(
          id: f.id,
          username: f.username,
          avatarUrl: f.avatarUrl,
          isOnline: online,
          currentGame: f.currentGame,
          lastSeen: f.lastSeen,
          level: f.level,
        );
      }
      return list;
    }
    return [];
  }

  // Add friend
  static Future<void> addFriend(Friend friend) async {
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    // Save friends to database
    final db = await DatabaseHelper.database;
    await db.insert(
      DatabaseHelper.friendshipsTable,
      {
        'user1_id': currentUser,
        'user2_id': friend.id,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Remove friend
  static Future<void> removeFriend(String friendId) async {
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    final db = await DatabaseHelper.database;
    await db.delete(
      DatabaseHelper.friendshipsTable,
      where: '(user1_id = ? AND user2_id = ?) OR (user1_id = ? AND user2_id = ?)',
      whereArgs: [currentUser, friendId, friendId, currentUser],
    );
  }

  // Send friend request
  static Future<void> sendFriendRequest(String fromUserId, String fromUsername, String toUserId, String toUsername) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get all friend requests (global storage)
    final requestsJson = prefs.getString('global_friend_requests');
    List<FriendRequest> requests = [];
    
    if (requestsJson != null) {
      final List<dynamic> requestsList = jsonDecode(requestsJson);
      requests = requestsList.map((json) => FriendRequest.fromJson(json)).toList();
    }
    
    // Check if request already exists
    if (requests.any((req) => req.fromUserId == fromUserId && req.toUserId == toUserId && req.status == FriendRequestStatus.pending)) {
      throw Exception('Friend request already sent');
    }
    
    final request = FriendRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: fromUserId,
      fromUsername: fromUsername,
      toUserId: toUserId,
      toUsername: toUsername,
      sentAt: DateTime.now(),
    );
    
    requests.add(request);
    
    // Save globally
    final requestsJsonNew = jsonEncode(requests.map((r) => r.toJson()).toList());
    await prefs.setString('global_friend_requests', requestsJsonNew);
  }

  // Get friend requests for a user
  static Future<List<FriendRequest>> getFriendRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return [];
    
    // Get all friend requests (global storage)
    final requestsJson = prefs.getString('global_friend_requests');
    if (requestsJson != null) {
      final List<dynamic> requestsList = jsonDecode(requestsJson);
      final allRequests = requestsList.map((json) => FriendRequest.fromJson(json)).toList();
      
      // Filter for current user (both sent and received)
      return allRequests.where((req) => 
        req.fromUserId == currentUser || req.toUserId == currentUser
      ).toList();
    }
    return [];
  }

  // Get pending friend requests for a user
  static Future<List<FriendRequest>> getPendingFriendRequests(String userId) async {
    final requests = await getFriendRequests();
    return requests.where((req) => req.toUserId == userId && req.status == FriendRequestStatus.pending).toList();
  }

  // Accept friend request
  static Future<void> acceptFriendRequest(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    // Get all friend requests (global storage)
    final requestsJson = prefs.getString('global_friend_requests');
    if (requestsJson == null) return;
    
    final List<dynamic> requestsList = jsonDecode(requestsJson);
    List<FriendRequest> requests = requestsList.map((json) => FriendRequest.fromJson(json)).toList();
    
    final requestIndex = requests.indexWhere((req) => req.id == requestId);
    if (requestIndex == -1) return;
    
    final request = requests[requestIndex];
    
    // Update request status
    requests[requestIndex] = FriendRequest(
      id: request.id,
      fromUserId: request.fromUserId,
      fromUsername: request.fromUsername,
      toUserId: request.toUserId,
      toUsername: request.toUsername,
      sentAt: request.sentAt,
      status: FriendRequestStatus.accepted,
    );
    
    // Add both users as friends - bidirectional friendship
    final friends = await getFriends();
    
    // Add the requester to the current user's friends
    final friend1 = Friend(
      id: request.fromUserId,
      username: request.fromUsername,
      avatarUrl: '',
      isOnline: true,
      currentGame: '',
      lastSeen: DateTime.now(),
      level: 1, // Default level
    );
    friends.add(friend1);
    
    // Get current user's username from AuthService
    final currentUserData = await AuthService.getCurrentUser();
    if (currentUserData == null) return;
    
    // Also add the current user to the requester's friends list
    final requesterFriend = Friend(
      id: currentUser,
      username: currentUserData.username,
      avatarUrl: '',
      isOnline: true,
      currentGame: '',
      lastSeen: DateTime.now(),
      level: 1, // Default level
    );
    
    // Get the requester's current friends list and add the current user
    final requesterFriendsJson = prefs.getString('$_friendsKey${request.fromUserId}');
    List<Friend> requesterFriends = [];
    if (requesterFriendsJson != null) {
      final List<dynamic> requesterFriendsList = jsonDecode(requesterFriendsJson);
      requesterFriends = requesterFriendsList.map((json) => Friend.fromJson(json)).toList();
    }
    requesterFriends.add(requesterFriend);
    
    // Save both friends lists to database
    final db = await DatabaseHelper.database;
    await db.insert(
      DatabaseHelper.friendshipsTable,
      {
        'user1_id': request.fromUserId,
        'user2_id': currentUser,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Save updated requests globally
    final requestsJsonNew = jsonEncode(requests.map((r) => r.toJson()).toList());
    await prefs.setString('global_friend_requests', requestsJsonNew);
  }

  // Decline friend request
  static Future<void> declineFriendRequest(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    // Get all friend requests (global storage)
    final requestsJson = prefs.getString('global_friend_requests');
    if (requestsJson == null) return;
    
    final List<dynamic> requestsList = jsonDecode(requestsJson);
    List<FriendRequest> requests = requestsList.map((json) => FriendRequest.fromJson(json)).toList();
    
    final requestIndex = requests.indexWhere((req) => req.id == requestId);
    if (requestIndex == -1) return;
    
    final request = requests[requestIndex];
    
    // Update request status
    requests[requestIndex] = FriendRequest(
      id: request.id,
      fromUserId: request.fromUserId,
      fromUsername: request.fromUsername,
      toUserId: request.toUserId,
      toUsername: request.toUsername,
      sentAt: request.sentAt,
      status: FriendRequestStatus.declined,
    );
    
    // Save updated requests globally
    final requestsJsonNew = jsonEncode(requests.map((r) => r.toJson()).toList());
    await prefs.setString('global_friend_requests', requestsJsonNew);
  }

  // Invites API
  static Future<void> sendGameInvite({
    required String toUserId,
    required String gameId,
    required String gameTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final me = await AuthService.getCurrentUser();
    if (me == null) throw Exception('Not logged in');

    final invite = GameInvite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: me.id,
      fromUsername: me.username,
      gameId: gameId,
      gameTitle: gameTitle,
      sentAt: DateTime.now(),
      read: false,
    );

    final key = '$_invitesKey$toUserId';
    final raw = prefs.getString(key);
    List<GameInvite> invites = [];
    if (raw != null) {
      final List<dynamic> list = jsonDecode(raw);
      invites = list.map((j) => GameInvite.fromJson(j)).toList();
    }
    invites.insert(0, invite);
    await prefs.setString(key, jsonEncode(invites.map((i) => i.toJson()).toList()));
  }

  static Future<List<GameInvite>> getInvites() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return [];
    final key = '$_invitesKey$currentUser';
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((j) => GameInvite.fromJson(j)).toList();
  }

  static Future<void> markAllInvitesRead() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    final key = '$_invitesKey$currentUser';
    final raw = prefs.getString(key);
    if (raw == null) return;
    final List<dynamic> list = jsonDecode(raw);
    final invites = list.map((j) => GameInvite.fromJson(j)).toList();
    final updated = invites
        .map((i) => GameInvite(
              id: i.id,
              fromUserId: i.fromUserId,
              fromUsername: i.fromUsername,
              gameId: i.gameId,
              gameTitle: i.gameTitle,
              sentAt: i.sentAt,
              read: true,
            ))
        .toList();
    await prefs.setString(key, jsonEncode(updated.map((i) => i.toJson()).toList()));
  }

  static Future<void> acceptInvite(String inviteId) async {
    final prefs = await SharedPreferences.getInstance();
    final me = await AuthService.getCurrentUser();
    if (me == null) return;
    final key = '$_invitesKey${me.id}';
    final raw = prefs.getString(key);
    if (raw == null) return;
    final List<dynamic> list = jsonDecode(raw);
    final invites = list.map((j) => GameInvite.fromJson(j)).toList();
    final idx = invites.indexWhere((i) => i.id == inviteId);
    if (idx == -1) return;
    final invite = invites[idx];
    invites.removeAt(idx);
    await prefs.setString(key, jsonEncode(invites.map((i) => i.toJson()).toList()));
    // Notify inviter via message
    await sendMessage(
      toUserId: invite.fromUserId,
      toUsername: invite.fromUsername,
      text: '${me.username} accepted your invite to ${invite.gameTitle}',
    );
  }

  static Future<void> declineInvite(String inviteId) async {
    final prefs = await SharedPreferences.getInstance();
    final me = await AuthService.getCurrentUser();
    if (me == null) return;
    final key = '$_invitesKey${me.id}';
    final raw = prefs.getString(key);
    if (raw == null) return;
    final List<dynamic> list = jsonDecode(raw);
    final invites = list.map((j) => GameInvite.fromJson(j)).toList();
    final idx = invites.indexWhere((i) => i.id == inviteId);
    if (idx == -1) return;
    final invite = invites[idx];
    invites.removeAt(idx);
    await prefs.setString(key, jsonEncode(invites.map((i) => i.toJson()).toList()));
    // Optional notify inviter
    await sendMessage(
      toUserId: invite.fromUserId,
      toUsername: invite.fromUsername,
      text: '${me.username} declined your invite to ${invite.gameTitle}',
    );
  }

  // Session Invites
  static Future<void> sendSessionInvite({
    required String toUserId,
    required String sessionId,
    required String sessionTitle,
    required String gameTitle,
  }) async {
    final db = await DatabaseHelper.database;
    final me = await AuthService.getCurrentUser();
    if (me == null) throw Exception('Not logged in');

    final invite = SessionInvite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: me.id,
      fromUsername: me.username,
      sessionId: sessionId,
      sessionTitle: sessionTitle,
      gameTitle: gameTitle,
      sentAt: DateTime.now(),
      read: false,
    );

    await db.insert(DatabaseHelper.sessionInvitesTable, {
      'id': invite.id,
      'from_user_id': invite.fromUserId,
      'from_username': invite.fromUsername,
      'to_user_id': toUserId,
      'session_id': invite.sessionId,
      'session_title': invite.sessionTitle,
      'game_title': invite.gameTitle,
      'sent_at': invite.sentAt.millisecondsSinceEpoch,
      'read': invite.read ? 1 : 0,
    });
  }

  static Future<List<SessionInvite>> getSessionInvites() async {
    final db = await DatabaseHelper.database;
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.sessionInvitesTable,
      where: 'to_user_id = ?',
      whereArgs: [currentUser],
      orderBy: 'sent_at DESC',
    );

    return maps.map((map) => SessionInvite(
      id: map['id'] as String,
      fromUserId: map['from_user_id'] as String,
      fromUsername: map['from_username'] as String,
      sessionId: map['session_id'] as String,
      sessionTitle: map['session_title'] as String,
      gameTitle: map['game_title'] as String,
      sentAt: DateTime.fromMillisecondsSinceEpoch(map['sent_at'] as int),
      read: (map['read'] as int) == 1,
    )).toList();
  }

  static Future<void> markAllSessionInvitesRead() async {
    final db = await DatabaseHelper.database;
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;

    await db.update(
      DatabaseHelper.sessionInvitesTable,
      {'read': 1},
      where: 'to_user_id = ?',
      whereArgs: [currentUser],
    );
  }

  static Future<void> acceptSessionInvite(String inviteId) async {
    final db = await DatabaseHelper.database;
    final me = await AuthService.getCurrentUser();
    if (me == null) return;

    // Get the invite
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.sessionInvitesTable,
      where: 'id = ? AND to_user_id = ?',
      whereArgs: [inviteId, me.id],
    );

    if (maps.isEmpty) return;
    final map = maps.first;

    // Remove the invite
    await db.delete(
      DatabaseHelper.sessionInvitesTable,
      where: 'id = ?',
      whereArgs: [inviteId],
    );

    // Notify inviter via message
    await sendMessage(
      toUserId: map['from_user_id'] as String,
      toUsername: map['from_username'] as String,
      text: '${me.username} accepted your session invite to ${map['session_title']}',
    );
  }

  static Future<void> declineSessionInvite(String inviteId) async {
    final db = await DatabaseHelper.database;
    final me = await AuthService.getCurrentUser();
    if (me == null) return;

    // Get the invite
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.sessionInvitesTable,
      where: 'id = ? AND to_user_id = ?',
      whereArgs: [inviteId, me.id],
    );

    if (maps.isEmpty) return;
    final map = maps.first;

    // Remove the invite
    await db.delete(
      DatabaseHelper.sessionInvitesTable,
      where: 'id = ?',
      whereArgs: [inviteId],
    );

    // Notify inviter via message
    await sendMessage(
      toUserId: map['from_user_id'] as String,
      toUsername: map['from_username'] as String,
      text: '${me.username} declined your session invite to ${map['session_title']}',
    );
  }

  // Messaging: return inbox threads for current user
  static Future<List<MessageThread>> getInbox() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return [];

    final inboxJson = prefs.getString('$_inboxKey$currentUser');
    if (inboxJson != null) {
      final List<dynamic> list = jsonDecode(inboxJson);
      return list.map((j) => MessageThread.fromJson(j)).toList();
    }
    return [];
  }

  // Send a message; creates threads on both sender and receiver
  static Future<void> sendMessage({
    required String toUserId,
    required String toUsername,
    required String text,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserData = await AuthService.getCurrentUser();
    if (currentUserData == null) {
      throw Exception('Not logged in');
    }

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: currentUserData.id,
      toUserId: toUserId,
      text: text,
      sentAt: DateTime.now(),
    );

    // Helper to upsert thread for a user
    Future<void> upsert(String userId, String otherUserId, String otherUsername) async {
      final key = '$_inboxKey$userId';
      final raw = prefs.getString(key);
      List<MessageThread> threads = [];
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        threads = list.map((j) => MessageThread.fromJson(j)).toList();
      }
      final idx = threads.indexWhere((t) => t.withUserId == otherUserId);
      if (idx == -1) {
        threads.insert(0, MessageThread(withUserId: otherUserId, withUsername: otherUsername, messages: [message]));
      } else {
        final existing = threads[idx];
        final updated = MessageThread(withUserId: existing.withUserId, withUsername: otherUsername, messages: [...existing.messages, message]);
        threads[idx] = updated;
      }
      await prefs.setString(key, jsonEncode(threads.map((t) => t.toJson()).toList()));
    }

    // Update sender inbox
    await upsert(currentUserData.id, toUserId, toUsername);

    // Update receiver inbox
    await upsert(toUserId, currentUserData.id, currentUserData.username);
  }

  // Get a single thread with another user for the current user
  static Future<MessageThread?> getThread(String otherUserId) async {
    final inbox = await getInbox();
    try {
      return inbox.firstWhere((t) => t.withUserId == otherUserId);
    } catch (_) {
      return null;
    }
  }

  // Mark all messages from otherUserId as read for the current user
  static Future<void> markThreadRead(String otherUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;

    final key = '$_inboxKey$currentUser';
    final raw = prefs.getString(key);
    if (raw == null) return;
    final List<dynamic> list = jsonDecode(raw);
    final threads = list.map((j) => MessageThread.fromJson(j)).toList();
    final idx = threads.indexWhere((t) => t.withUserId == otherUserId);
    if (idx == -1) return;

    final thread = threads[idx];
    final updatedMessages = thread.messages.map((m) {
      if (m.toUserId == currentUser) {
        return ChatMessage(
          id: m.id,
          fromUserId: m.fromUserId,
          toUserId: m.toUserId,
          text: m.text,
          sentAt: m.sentAt,
          read: true,
        );
      }
      return m;
    }).toList();

    threads[idx] = MessageThread(
      withUserId: thread.withUserId,
      withUsername: thread.withUsername,
      messages: updatedMessages,
    );

    await prefs.setString(key, jsonEncode(threads.map((t) => t.toJson()).toList()));
  }

  // Session Chat (very simple local persistence per session)
  static Future<List<SessionChatMessage>> getSessionChat(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_sessionChatKey$sessionId');
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((j) => SessionChatMessage.fromJson(j)).toList();
  }

  static Future<void> sendSessionChatMessage(String sessionId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final me = await AuthService.getCurrentUser();
    if (me == null) throw Exception('Not logged in');

    final msg = SessionChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: me.id,
      fromUsername: me.username,
      text: text,
      sentAt: DateTime.now(),
    );

    final key = '$_sessionChatKey$sessionId';
    final raw = prefs.getString(key);
    List<SessionChatMessage> messages = [];
    if (raw != null) {
      final List<dynamic> list = jsonDecode(raw);
      messages = list.map((j) => SessionChatMessage.fromJson(j)).toList();
    }
    messages.add(msg);
    await prefs.setString(key, jsonEncode(messages.map((m) => m.toJson()).toList()));
  }

  // Migration helper - converts existing SharedPreferences data to SQLite
  static Future<void> migrateFromSharedPreferences() async {
    if (!await DatabaseHelper.needsMigration()) {
      print('DEBUG: Migration already completed, skipping');
      return;
    }
    
    print('DEBUG: Starting migration from SharedPreferences to SQLite');
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Migrate users
      final usersJson = prefs.getString('registered_users');
      if (usersJson != null) {
        final List<dynamic> usersList = jsonDecode(usersJson);
        final db = await DatabaseHelper.database;
        
        for (final userJson in usersList) {
          final user = AuthUser.fromJson(userJson);
          await db.insert(
            DatabaseHelper.usersTable,
            {
              'id': user.id,
              'username': user.username,
              'email': user.email,
              'password': user.password,
              'created_at': user.createdAt.millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        print('DEBUG: Migrated ${usersList.length} users');
      }
      
      // Mark migration as complete
      await DatabaseHelper.markMigrationComplete();
      print('DEBUG: Migration completed successfully');
    } catch (e) {
      print('DEBUG: Migration failed: $e');
    }
  }


  // Clear all user data (for new accounts)
  static Future<void> clearAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await _getCurrentUserId();
    if (currentUser == null) return;
    
    await prefs.remove('$_libraryKey$currentUser');
    await prefs.remove('$_profileKey$currentUser');
    await prefs.remove('$_achievementsKey$currentUser');
    await prefs.remove('$_friendsKey$currentUser');
    await prefs.remove('$_inboxKey$currentUser');
    
    // Don't clear global reviews - they should be visible to all users
    
    // Clear friend requests for this user from global storage
    final requestsJson = prefs.getString('global_friend_requests');
    if (requestsJson != null) {
      final List<dynamic> requestsList = jsonDecode(requestsJson);
      List<FriendRequest> requests = requestsList.map((json) => FriendRequest.fromJson(json)).toList();
      
      // Remove all requests involving this user
      requests.removeWhere((req) => req.fromUserId == currentUser || req.toUserId == currentUser);
      
      final requestsJsonNew = jsonEncode(requests.map((r) => r.toJson()).toList());
      await prefs.setString('global_friend_requests', requestsJsonNew);
    }
  }

  // Helper method to get current user ID
  static Future<String?> _getCurrentUserId() async {
    final userId = await DatabaseHelper.getAppState('current_user_id');
    print('DEBUG: Retrieved current user ID: $userId');
    
    // If no user ID found, try to get it from AuthService
    if (userId == null) {
      print('DEBUG: No user ID in database, checking AuthService');
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser != null) {
        print('DEBUG: Found current user from AuthService: ${currentUser.id}');
        // Store the user ID for future use
        await DatabaseHelper.setAppState('current_user_id', currentUser.id);
        return currentUser.id;
      } else {
        print('DEBUG: No current user found in AuthService either');
      }
    }
    
    return userId;
  }
}

