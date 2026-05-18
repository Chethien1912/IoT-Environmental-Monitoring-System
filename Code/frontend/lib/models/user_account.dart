class UserAccount {
  const UserAccount({
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

  bool get isAdmin => role == 'admin';

  UserAccount copyWith({
    int? id,
    String? username,
    String? role,
    bool? isActive,
    String? createdAt,
  }) {
    return UserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => value is num ? value.toInt() : 0;
    String asString(dynamic value) => value is String ? value : '';
    bool asBool(dynamic value) => value is bool ? value : value == 1;

    return UserAccount(
      id: asInt(json['id']),
      username: asString(json['username']),
      role: asString(json['role']),
      isActive: asBool(json['is_active']),
      createdAt: asString(json['created_at']),
    );
  }
}
