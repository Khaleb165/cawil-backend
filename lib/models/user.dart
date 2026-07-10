class User {
  final int id;
  final String? uid;
  final String email;
  final String username;
  final String avatarUrl;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    this.uid,
    required this.email,
    required this.username,
    required this.avatarUrl,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        uid: json['uid'] as String?,
        email: json['email'] as String,
        username: json['username'] as String,
        avatarUrl: (json['avatar_url'] as String?) ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.user,
        ),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'email': email,
        'username': username,
        'avatar_url': avatarUrl,
        'role': role.name,
      };
}

enum UserRole { user, admin }

class RegisterRequest {
  final String email;
  final String password;
  final String username;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.username,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'username': username,
      };
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class AuthResponse {
  final User user;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'access_token': accessToken,
        'refresh_token': refreshToken,
      };
}
