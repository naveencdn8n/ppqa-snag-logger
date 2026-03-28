import 'package:flutter/material.dart';

// ─── Location ────────────────────────────────────────────────────────────────
enum SnagLocation { tower1, tower2, tower3, tower4, nta, commonArea, club, others }

extension SnagLocationExt on SnagLocation {
  String get label {
    switch (this) {
      case SnagLocation.tower1:      return 'Tower 1';
      case SnagLocation.tower2:      return 'Tower 2';
      case SnagLocation.tower3:      return 'Tower 3';
      case SnagLocation.tower4:      return 'Tower 4';
      case SnagLocation.nta:         return 'NTA';
      case SnagLocation.commonArea:  return 'Common Area';
      case SnagLocation.club:        return 'Club';
      case SnagLocation.others:      return 'Others';
    }
  }
}

// ─── Flat No ─────────────────────────────────────────────────────────────────
enum FlatNo { unit1, unit2, unit3, unit4, unit5, others }

extension FlatNoExt on FlatNo {
  String get label {
    switch (this) {
      case FlatNo.unit1:  return 'Unit 1';
      case FlatNo.unit2:  return 'Unit 2';
      case FlatNo.unit3:  return 'Unit 3';
      case FlatNo.unit4:  return 'Unit 4';
      case FlatNo.unit5:  return 'Unit 5';
      case FlatNo.others: return 'Others';
    }
  }
}

// ─── Element / Room ──────────────────────────────────────────────────────────
enum SnagElement {
  bedroom1, bedroom2, bedroom3, kitchen, hall, studyRoom, balcony, commonArea, others
}

extension SnagElementExt on SnagElement {
  String get label {
    switch (this) {
      case SnagElement.bedroom1:    return 'Bedroom 1';
      case SnagElement.bedroom2:    return 'Bedroom 2';
      case SnagElement.bedroom3:    return 'Bedroom 3';
      case SnagElement.kitchen:     return 'Kitchen';
      case SnagElement.hall:        return 'Hall';
      case SnagElement.studyRoom:   return 'Study Room';
      case SnagElement.balcony:     return 'Balcony';
      case SnagElement.commonArea:  return 'Common Area';
      case SnagElement.others:      return 'Others';
    }
  }
}

// ─── Trade ───────────────────────────────────────────────────────────────────
enum SnagTrade {
  tiling, paintAndFinishes, carpentryAndMillwork, waterproofing,
  electrical, plumbing, hvac, fireDetection, sanitaryFittings,
  ironmongery, glazingAndWindows, falseCeiling, externalFinishes, other
}

extension SnagTradeExt on SnagTrade {
  String get label {
    switch (this) {
      case SnagTrade.tiling:               return 'Tiling';
      case SnagTrade.paintAndFinishes:     return 'Paint & Finishes';
      case SnagTrade.carpentryAndMillwork: return 'Carpentry & Millwork';
      case SnagTrade.waterproofing:        return 'Waterproofing';
      case SnagTrade.electrical:           return 'Electrical';
      case SnagTrade.plumbing:             return 'Plumbing';
      case SnagTrade.hvac:                 return 'HVAC';
      case SnagTrade.fireDetection:        return 'Fire Detection';
      case SnagTrade.sanitaryFittings:     return 'Sanitary Fittings';
      case SnagTrade.ironmongery:          return 'Ironmongery';
      case SnagTrade.glazingAndWindows:    return 'Glazing & Windows';
      case SnagTrade.falseCeiling:         return 'False Ceiling';
      case SnagTrade.externalFinishes:     return 'External Finishes';
      case SnagTrade.other:                return 'Other';
    }
  }
}

// ─── Severity ─────────────────────────────────────────────────────────────────
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

// ─── Status ──────────────────────────────────────────────────────────────────
enum SnagStatus { open, inProgress, closed }

extension SnagStatusExt on SnagStatus {
  String get label {
    switch (this) {
      case SnagStatus.open:       return 'Open';
      case SnagStatus.inProgress: return 'In Progress';
      case SnagStatus.closed:     return 'Closed';
    }
  }

  Color get color {
    switch (this) {
      case SnagStatus.open:       return const Color(0xFFE65100);
      case SnagStatus.inProgress: return const Color(0xFF1565C0);
      case SnagStatus.closed:     return const Color(0xFF2E7D32);
    }
  }
}

// ─── Defects List Trade (broader filter) ─────────────────────────────────────
enum DefectsListTrade { civil, mep, general }

extension DefectsListTradeExt on DefectsListTrade {
  String get label {
    switch (this) {
      case DefectsListTrade.civil:   return 'Civil';
      case DefectsListTrade.mep:     return 'MEP';
      case DefectsListTrade.general: return 'General';
    }
  }
}
