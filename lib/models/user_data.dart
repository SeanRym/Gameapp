
// User Profile and Library Management
class UserProfile {
  final String id;
  final String username;
  final String email;
  final String avatarUrl;
  final int level;
  final int xp;
  final String country;
  final DateTime joinDate;
  final List<String> ownedGames;
  final List<String> wishlist;
  final List<String> friends;
  final List<String> achievements;
  final Map<String, int> gamePlaytime; // gameId -> hours played
  final Map<String, double> gameRatings; // gameId -> user rating

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.level,
    required this.xp,
    required this.country,
    required this.joinDate,
    required this.ownedGames,
    required this.wishlist,
    required this.friends,
    required this.achievements,
    required this.gamePlaytime,
    required this.gameRatings,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      level: json['level'],
      xp: json['xp'],
      country: json['country'],
      joinDate: DateTime.parse(json['joinDate']),
      ownedGames: List<String>.from(json['ownedGames']),
      wishlist: List<String>.from(json['wishlist']),
      friends: List<String>.from(json['friends']),
      achievements: List<String>.from(json['achievements']),
      gamePlaytime: Map<String, int>.from(json['gamePlaytime']),
      gameRatings: Map<String, double>.from(json['gameRatings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'level': level,
      'xp': xp,
      'country': country,
      'joinDate': joinDate.toIso8601String(),
      'ownedGames': ownedGames,
      'wishlist': wishlist,
      'friends': friends,
      'achievements': achievements,
      'gamePlaytime': gamePlaytime,
      'gameRatings': gameRatings,
    };
  }
}

// Achievement System
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final int xpReward;
  final AchievementType type;
  final Map<String, dynamic> requirements;
  final bool isSecret;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.xpReward,
    required this.type,
    required this.requirements,
    this.isSecret = false,
  });
}

enum AchievementType {
  gaming,
  social,
  collection,
  milestone,
  special,
}

class UserAchievement {
  final String achievementId;
  final DateTime unlockedAt;
  final int progress;
  final bool isUnlocked;

  UserAchievement({
    required this.achievementId,
    required this.unlockedAt,
    required this.progress,
    required this.isUnlocked,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      achievementId: json['achievementId'],
      unlockedAt: DateTime.parse(json['unlockedAt']),
      progress: json['progress'],
      isUnlocked: json['isUnlocked'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievementId': achievementId,
      'unlockedAt': unlockedAt.toIso8601String(),
      'progress': progress,
      'isUnlocked': isUnlocked,
    };
  }
}

// Game Reviews and Ratings
class GameReview {
  final String id;
  final String gameId;
  final String userId;
  final String username;
  final String avatarUrl;
  final double rating;
  final String title;
  final String content;
  final DateTime createdAt;
  final int helpfulVotes;
  final bool isVerified;
  final List<String> tags;

  GameReview({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.rating,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.helpfulVotes,
    required this.isVerified,
    required this.tags,
  });

  factory GameReview.fromJson(Map<String, dynamic> json) {
    return GameReview(
      id: json['id'],
      gameId: json['gameId'],
      userId: json['userId'],
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      rating: json['rating'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      helpfulVotes: json['helpfulVotes'],
      isVerified: json['isVerified'],
      tags: List<String>.from(json['tags']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameId': gameId,
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'rating': rating,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'helpfulVotes': helpfulVotes,
      'isVerified': isVerified,
      'tags': tags,
    };
  }
}

// Social Features
class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final String toUsername;
  final DateTime sentAt;
  final FriendRequestStatus status;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
    required this.sentAt,
    this.status = FriendRequestStatus.pending,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      fromUserId: json['fromUserId'],
      fromUsername: json['fromUsername'],
      toUserId: json['toUserId'],
      toUsername: json['toUsername'],
      sentAt: DateTime.parse(json['sentAt']),
      status: FriendRequestStatus.values[json['status']],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'toUserId': toUserId,
      'toUsername': toUsername,
      'sentAt': sentAt.toIso8601String(),
      'status': status.index,
    };
  }
}

enum FriendRequestStatus {
  pending,
  accepted,
  declined,
}

class Friend {
  final String id;
  final String username;
  final String avatarUrl;
  final bool isOnline;
  final String currentGame;
  final DateTime lastSeen;
  final int level;

  Friend({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.isOnline,
    required this.currentGame,
    required this.lastSeen,
    required this.level,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      isOnline: json['isOnline'],
      currentGame: json['currentGame'],
      lastSeen: DateTime.parse(json['lastSeen']),
      level: json['level'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'isOnline': isOnline,
      'currentGame': currentGame,
      'lastSeen': lastSeen.toIso8601String(),
      'level': level,
    };
  }
}

class GameSession {
  final String id;
  final String gameId;
  final String gameTitle;
  final DateTime startTime;
  final DateTime? endTime;
  final List<String> participants;
  final SessionType type;

  GameSession({
    required this.id,
    required this.gameId,
    required this.gameTitle,
    required this.startTime,
    this.endTime,
    required this.participants,
    required this.type,
  });
}

enum SessionType {
  singleplayer,
  multiplayer,
  coOp,
  competitive,
}

// Game Installation
class GameInstallation {
  final String gameId;
  final String gameTitle;
  final String version;
  final String installPath;
  final double sizeGB;
  final InstallationStatus status;
  final DateTime installDate;
  final DateTime? lastPlayed;
  final int playtimeHours;
  final bool autoUpdate;

  GameInstallation({
    required this.gameId,
    required this.gameTitle,
    required this.version,
    required this.installPath,
    required this.sizeGB,
    required this.status,
    required this.installDate,
    this.lastPlayed,
    required this.playtimeHours,
    required this.autoUpdate,
  });
}

enum InstallationStatus {
  notInstalled,
  downloading,
  installing,
  installed,
  updating,
  error,
}

// Game Library Item
class LibraryGame {
  final String gameId;
  final String title;
  final String imageUrl;
  final DateTime purchaseDate;
  final double pricePaid;
  final int playtimeHours;
  final DateTime? lastPlayed;
  final bool isInstalled;
  final String version;
  final List<String> achievements;
  final double userRating;
  final bool isFavorite;

  LibraryGame({
    required this.gameId,
    required this.title,
    required this.imageUrl,
    required this.purchaseDate,
    required this.pricePaid,
    required this.playtimeHours,
    this.lastPlayed,
    required this.isInstalled,
    required this.version,
    required this.achievements,
    required this.userRating,
    required this.isFavorite,
  });

  factory LibraryGame.fromJson(Map<String, dynamic> json) {
    return LibraryGame(
      gameId: json['gameId'],
      title: json['title'],
      imageUrl: json['imageUrl'],
      purchaseDate: DateTime.parse(json['purchaseDate']),
      pricePaid: json['pricePaid'],
      playtimeHours: json['playtimeHours'],
      lastPlayed: json['lastPlayed'] != null ? DateTime.parse(json['lastPlayed']) : null,
      isInstalled: json['isInstalled'],
      version: json['version'],
      achievements: List<String>.from(json['achievements']),
      userRating: json['userRating'],
      isFavorite: json['isFavorite'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'title': title,
      'imageUrl': imageUrl,
      'purchaseDate': purchaseDate.toIso8601String(),
      'pricePaid': pricePaid,
      'playtimeHours': playtimeHours,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'isInstalled': isInstalled,
      'version': version,
      'achievements': achievements,
      'userRating': userRating,
      'isFavorite': isFavorite,
    };
  }
}

// Messaging
class ChatMessage {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String text;
  final DateTime sentAt;
  final bool read;

  ChatMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.sentAt,
    this.read = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      fromUserId: json['fromUserId'],
      toUserId: json['toUserId'],
      text: json['text'],
      sentAt: DateTime.parse(json['sentAt']),
      read: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'text': text,
      'sentAt': sentAt.toIso8601String(),
      'read': read,
    };
  }
}

class MessageThread {
  final String withUserId;
  final String withUsername;
  final List<ChatMessage> messages;

  MessageThread({
    required this.withUserId,
    required this.withUsername,
    required this.messages,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      withUserId: json['withUserId'],
      withUsername: json['withUsername'],
      messages: (json['messages'] as List<dynamic>)
          .map((m) => ChatMessage.fromJson(m))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'withUserId': withUserId,
      'withUsername': withUsername,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

// Session group chat message (simple model for session chat)
class SessionChatMessage {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String text;
  final DateTime sentAt;

  SessionChatMessage({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.text,
    required this.sentAt,
  });

  factory SessionChatMessage.fromJson(Map<String, dynamic> json) {
    return SessionChatMessage(
      id: json['id'],
      fromUserId: json['fromUserId'],
      fromUsername: json['fromUsername'],
      text: json['text'],
      sentAt: DateTime.parse(json['sentAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'text': text,
      'sentAt': sentAt.toIso8601String(),
    };
  }
}

// Game Invites
class GameInvite {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String? gameId;
  final String gameTitle;
  final DateTime sentAt;
  final bool read;

  GameInvite({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.gameId,
    required this.gameTitle,
    required this.sentAt,
    this.read = false,
  });

  factory GameInvite.fromJson(Map<String, dynamic> json) {
    return GameInvite(
      id: json['id'],
      fromUserId: json['fromUserId'],
      fromUsername: json['fromUsername'],
      gameId: json['gameId'],
      gameTitle: json['gameTitle'],
      sentAt: DateTime.parse(json['sentAt']),
      read: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'gameId': gameId,
      'gameTitle': gameTitle,
      'sentAt': sentAt.toIso8601String(),
      'read': read,
    };
  }
}

// Session Invites
class SessionInvite {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String sessionId;
  final String sessionTitle;
  final String gameTitle;
  final DateTime sentAt;
  final bool read;

  SessionInvite({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.sessionId,
    required this.sessionTitle,
    required this.gameTitle,
    required this.sentAt,
    this.read = false,
  });

  factory SessionInvite.fromJson(Map<String, dynamic> json) {
    return SessionInvite(
      id: json['id'],
      fromUserId: json['fromUserId'],
      fromUsername: json['fromUsername'],
      sessionId: json['sessionId'],
      sessionTitle: json['sessionTitle'],
      gameTitle: json['gameTitle'],
      sentAt: DateTime.parse(json['sentAt']),
      read: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'gameTitle': gameTitle,
      'sentAt': sentAt.toIso8601String(),
      'read': read,
    };
  }
}