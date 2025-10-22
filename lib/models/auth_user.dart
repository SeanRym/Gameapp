class AuthUser {
  final String id;
  final String username;
  final String email;
  final String password; // In production, this should be hashed
  final DateTime createdAt;
  final bool isEmailVerified;
  final int level;

  AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.createdAt,
    this.isEmailVerified = false,
    this.level = 1,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      password: json['password'],
      createdAt: DateTime.parse(json['createdAt']),
      isEmailVerified: json['isEmailVerified'] ?? false,
      level: json['level'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'level': level,
    };
  }

  AuthUser copyWith({
    String? id,
    String? username,
    String? email,
    String? password,
    DateTime? createdAt,
    bool? isEmailVerified,
    int? level,
  }) {
    return AuthUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      level: level ?? this.level,
    );
  }
}

class LoginCredentials {
  final String usernameOrEmail;
  final String password;

  LoginCredentials({
    required this.usernameOrEmail,
    required this.password,
  });
}

class SignUpCredentials {
  final String username;
  final String email;
  final String password;
  final String confirmPassword;

  SignUpCredentials({
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });
}
