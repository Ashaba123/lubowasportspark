/// WordPress REST API user (wp/v2/users/me).
class WpUser {
  const WpUser({
    required this.id,
    required this.name,
    this.username,
    this.email,
  });

  final int id;
  final String name;
  final String? username;
  final String? email;

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory WpUser.fromJson(Map<String, dynamic> json) => WpUser(
        id: _toInt(json['id']),
        name: (json['name'] as String?) ??
            (json['display_name'] as String?) ??
            (json['username'] as String?) ??
            '',
        username: (json['username'] as String?) ?? (json['slug'] as String?),
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (username != null) 'username': username,
        if (email != null) 'email': email,
      };
}

