class UserModel {
  final String id;
  final String username;
  final String email;
  final String role;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
  });

  String get initials {
    final parts = username.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : 'U';
  }
}
