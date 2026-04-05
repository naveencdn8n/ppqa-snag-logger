import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String id;
  final String username;
  final String email;
  final String role;
  final String? photoUrl;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.photoUrl,
  });

  /// Maps a signed-in Firebase [User] to a [UserModel].
  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      id: user.uid,
      username: user.displayName ?? user.email?.split('@').first ?? 'User',
      email: user.email ?? '',
      role: 'auditor',
      photoUrl: user.photoURL,
    );
  }

  String get initials {
    final parts = username.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : 'U';
  }
}
