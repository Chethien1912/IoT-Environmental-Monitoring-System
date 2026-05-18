class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String username;
  final String role;
  final bool isActive;
  final String createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => value is num ? value.toInt() : 0;
    String asString(dynamic value) => value is String ? value : '';
    bool asBool(dynamic value) => value is bool ? value : value == 1;

    return AuthUser(
      id: asInt(json['id']),
      username: asString(json['username']),
      role: asString(json['role']),
      isActive: asBool(json['is_active']),
      createdAt: asString(json['created_at']),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    String asString(dynamic value) => value is String ? value : '';
    final userJson = json['user'];

    return AuthSession(
      accessToken: asString(json['accessToken']),
      refreshToken: asString(json['refreshToken']),
      user: userJson is Map<String, dynamic>
          ? AuthUser.fromJson(userJson)
          : const AuthUser(
              id: 0,
              username: '',
              role: '',
              isActive: false,
              createdAt: '',
            ),
    );
  }
}
