import 'package:flutter/material.dart';

// ─── Project Status ───────────────────────────────────────────────────────────
// Lifecycle states for a project.
enum ProjectStatus { active, onHold, completed, archived }

extension ProjectStatusExt on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.active:    return 'Active';
      case ProjectStatus.onHold:    return 'On Hold';
      case ProjectStatus.completed: return 'Completed';
      case ProjectStatus.archived:  return 'Archived';
    }
  }

  String get firestoreValue {
    switch (this) {
      case ProjectStatus.active:    return 'active';
      case ProjectStatus.onHold:    return 'onHold';
      case ProjectStatus.completed: return 'completed';
      case ProjectStatus.archived:  return 'archived';
    }
  }

  Color get color {
    switch (this) {
      case ProjectStatus.active:    return const Color(0xFF2E7D32); // green
      case ProjectStatus.onHold:    return const Color(0xFFE65100); // orange
      case ProjectStatus.completed: return const Color(0xFF1565C0); // blue
      case ProjectStatus.archived:  return const Color(0xFF78909C); // grey
    }
  }

  static ProjectStatus fromFirestore(String? raw) {
    switch (raw) {
      case 'onHold':    return ProjectStatus.onHold;
      case 'completed': return ProjectStatus.completed;
      case 'archived':  return ProjectStatus.archived;
      default:          return ProjectStatus.active;
    }
  }
}

// ─── Project Member Role ──────────────────────────────────────────────────────
// Per-project role — separate from the global UserModel.role used in v1.
// A user can be a Supervisor on Project A and an Inspector on Project B.
enum ProjectMemberRole { projectManager, supervisor, inspector, viewer }

extension ProjectMemberRoleExt on ProjectMemberRole {
  String get label {
    switch (this) {
      case ProjectMemberRole.projectManager: return 'Project Manager';
      case ProjectMemberRole.supervisor:     return 'Supervisor';
      case ProjectMemberRole.inspector:      return 'Inspector';
      case ProjectMemberRole.viewer:         return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case ProjectMemberRole.projectManager:
        return 'Manages project settings, members, and config. Can do everything a Supervisor can.';
      case ProjectMemberRole.supervisor:
        return 'Views all snags, changes status on anyone\'s snags, oversees progress.';
      case ProjectMemberRole.inspector:
        return 'Logs snags, captures evidence, updates status of own snags.';
      case ProjectMemberRole.viewer:
        return 'Read-only access — can view snags and reports but cannot log or change anything.';
    }
  }

  String get firestoreValue {
    switch (this) {
      case ProjectMemberRole.projectManager: return 'projectManager';
      case ProjectMemberRole.supervisor:     return 'supervisor';
      case ProjectMemberRole.inspector:      return 'inspector';
      case ProjectMemberRole.viewer:         return 'viewer';
    }
  }

  /// Permission checks
  bool get canLogSnags =>
      this == ProjectMemberRole.inspector ||
      this == ProjectMemberRole.supervisor ||
      this == ProjectMemberRole.projectManager;

  bool get canChangeAnyStatus =>
      this == ProjectMemberRole.supervisor ||
      this == ProjectMemberRole.projectManager;

  bool get canChangeOwnStatus => canLogSnags;

  bool get canManageProject => this == ProjectMemberRole.projectManager;

  static ProjectMemberRole fromFirestore(String? raw) {
    switch (raw) {
      case 'projectManager': return ProjectMemberRole.projectManager;
      case 'supervisor':     return ProjectMemberRole.supervisor;
      case 'viewer':         return ProjectMemberRole.viewer;
      default:               return ProjectMemberRole.inspector;
    }
  }
}

// ─── Severity ─────────────────────────────────────────────────────────────────
// Fixed set — not admin-configurable.
enum SnagSeverity { redLine, major, minor }

extension SnagSeverityExt on SnagSeverity {
  String get label {
    switch (this) {
      case SnagSeverity.redLine: return 'Red Line';
      case SnagSeverity.major:   return 'Major';
      case SnagSeverity.minor:   return 'Minor';
    }
  }

  Color get color {
    switch (this) {
      case SnagSeverity.redLine: return const Color(0xFFB71C1C);
      case SnagSeverity.major:   return const Color(0xFFE65100);
      case SnagSeverity.minor:   return const Color(0xFFF9A825);
    }
  }
}

// ─── Status ───────────────────────────────────────────────────────────────────
// Fixed set — not admin-configurable.
enum SnagStatus { open, inProgress, closed, void_ }

extension SnagStatusExt on SnagStatus {
  String get label {
    switch (this) {
      case SnagStatus.open:       return 'Open';
      case SnagStatus.inProgress: return 'In Progress';
      case SnagStatus.closed:     return 'Closed';
      case SnagStatus.void_:      return 'Void';
    }
  }

  /// The Firestore string value stored / read from the database.
  String get firestoreValue {
    switch (this) {
      case SnagStatus.open:       return 'open';
      case SnagStatus.inProgress: return 'inProgress';
      case SnagStatus.closed:     return 'closed';
      case SnagStatus.void_:      return 'void';
    }
  }

  Color get color {
    switch (this) {
      case SnagStatus.open:       return const Color(0xFFE65100);
      case SnagStatus.inProgress: return const Color(0xFF1565C0);
      case SnagStatus.closed:     return const Color(0xFF2E7D32);
      case SnagStatus.void_:      return const Color(0xFF78909C);
    }
  }

  /// Parses the raw Firestore string back to [SnagStatus].
  static SnagStatus fromFirestore(String? raw) {
    switch (raw) {
      case 'open':       return SnagStatus.open;
      case 'inProgress': return SnagStatus.inProgress;
      case 'closed':     return SnagStatus.closed;
      case 'void':       return SnagStatus.void_;
      default:           return SnagStatus.open;
    }
  }
}
