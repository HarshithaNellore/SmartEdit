class UserModel {
  final String id;
  final String name;
  final String email;
  final String avatarColor;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarColor = '#6C63FF',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarColor: json['avatar_color'] ?? '#6C63FF',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar_color': avatarColor,
      };

  /// Returns the first letter of the name for avatar display.
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
