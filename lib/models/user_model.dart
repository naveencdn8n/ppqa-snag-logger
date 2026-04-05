import 'package:firebase_auth/firebase_auth.dart';

/// Valid roles stored in Firestore `users/{uid}.role`
class UserRoles {
  static const inspector = 'inspector';
  static const supervisor = 'supervisor';
  static const viewer = 'viewer';
}

/// Valid statuses stored in Firestore `users/{uid}.status`
class UserStatuses {
  static const active = 'active';
  static const blocked = 'blocked';
}

class UserModel {
  final String id;
  final String username;
  final String email;
  final String role;
  final String status;
  final String? photoUrl;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.status,
    this.photoUrl,
  });

  /// Creates a [UserModel] from a Firebase [User] and Firestore profile data.
  /// [profileData] should contain 'role' and 'status' from the `users` collection.
  factory UserModel.fromFirebaseUser(
    User user, {
    Map<String, dynamic>? profileData,
  }) {
    return UserModel(
      id: user.uid,
      username: user.displayName ?? user.email?.split('@').first ?? 'User',
      email: user.email ?? '',
      role: (profileData?['role'] as String?) ?? UserRoles.inspector,
      status: (profileData?['status'] as String?) ?? UserStatuses.active,
      photoUrl: user.photoURL,
    );
  }

  // ── Role checks ──────────────────────────────────────────────────────────────
  bool get isInspector => role == UserRoles.inspector;
  bool get isSupervisor => role == UserRoles.supervisor;
  bool get isViewer => role == UserRoles.viewer;
  bool get isBlocked => status == UserStatuses.blocked;

  // ── Permission checks ────────────────────────────────────────────────────────
  /// Can create new snags and capture evidence.
  bool get canLogSnags => !isViewer && !isBlocked;

  /// Can change status on ANY snag (not just own).
  bool get canChangeAnyStatus => isSupervisor && !isBlocked;

  /// Can change status on their own snags.
  bool get canChangeOwnStatus => (isInspector || isSupervisor) && !isBlocked;

  /// Read-only access — cannot log or change anything.
  bool get isViewOnly => isViewer || isBlocked;

  // ── Display helpers ──────────────────────────────────────────────────────────
  String get roleLabel {
    switch (role) {
      case UserRoles.supervisor:
        return 'Supervisor';
      case UserRoles.viewer:
        return 'Viewer';
      default:
        return 'Inspector';
    }
  }

  String get initials {
    final parts = username.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : 'U';
  }
}
