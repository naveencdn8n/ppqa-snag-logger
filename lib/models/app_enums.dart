import 'package:flutter/material.dart';

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
