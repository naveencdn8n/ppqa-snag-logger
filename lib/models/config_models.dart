/// Lightweight data classes for Firestore-driven configuration.
/// These are populated by [ConfigService] and consumed by [AppState].

class DefectItem {
  final String id;
  final String name;

  const DefectItem({required this.id, required this.name});
}

class ElementItem {
  final String id;
  final String name;
  final List<DefectItem> defects;

  const ElementItem({
    required this.id,
    required this.name,
    required this.defects,
  });
}

class TradeItem {
  final String id;
  final String name;
  final List<ElementItem> elements;

  const TradeItem({
    required this.id,
    required this.name,
    required this.elements,
  });
}

class LocationItem {
  final String id;
  final String name;
  final List<String> floors;
  final List<String> units;
  /// Rooms within each unit — e.g. "Living Room", "Bedroom 1", "Kitchen".
  /// Level 4 of the Tower→Floor→Unit→Room→Element hierarchy.
  final List<String> rooms;

  const LocationItem({
    required this.id,
    required this.name,
    required this.floors,
    required this.units,
    this.rooms = const [],
  });
}
