import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/config_models.dart';

/// Streams the admin-configured data from Firestore:
///   • Trade → Element → Defect tree  (used in the Log Snag form)
///   • Locations with floors & units   (used in the Log Snag form)
///
/// All reads are project-scoped (v2):
///   `projects/{projectId}/trades`
///   `projects/{projectId}/locations`
class ConfigService {
  final _db = FirebaseFirestore.instance;

  // ── Trades tree ─────────────────────────────────────────────────────────────

  /// Emits the full Trade→Element→Defect tree whenever any trade document
  /// changes. Elements and defects are fetched with one-off [get] calls so
  /// we don't open thousands of listeners for subcollections.
  Stream<List<TradeItem>> tradesStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('trades')
        .orderBy('name')
        .snapshots()
        .asyncMap((snap) => _buildTradesTree(snap, projectId));
  }

  Future<List<TradeItem>> _buildTradesTree(
    QuerySnapshot tradesSnap,
    String projectId,
  ) async {
    final result = <TradeItem>[];
    final tradesBase = _db
        .collection('projects')
        .doc(projectId)
        .collection('trades');

    for (final tradeDoc in tradesSnap.docs) {
      final elementsSnap = await tradesBase
          .doc(tradeDoc.id)
          .collection('elements')
          .orderBy('name')
          .get();

      final elements = <ElementItem>[];

      for (final elemDoc in elementsSnap.docs) {
        final defectsSnap = await tradesBase
            .doc(tradeDoc.id)
            .collection('elements')
            .doc(elemDoc.id)
            .collection('defects')
            .orderBy('name')
            .get();

        elements.add(ElementItem(
          id: elemDoc.id,
          name: elemDoc['name'] as String,
          defects: defectsSnap.docs
              .map((d) => DefectItem(id: d.id, name: d['name'] as String))
              .toList(),
        ));
      }

      result.add(TradeItem(
        id: tradeDoc.id,
        name: tradeDoc['name'] as String,
        elements: elements,
      ));
    }

    return result;
  }

  // ── Locations ────────────────────────────────────────────────────────────────

  /// Emits the locations list (with floors & units) whenever the collection
  /// changes.
  Stream<List<LocationItem>> locationsStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('locations')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              return LocationItem(
                id: d.id,
                name: d['name'] as String? ?? '',
                floors: List<String>.from(d['floors'] ?? []),
                units:  List<String>.from(d['units']  ?? []),
                rooms:  List<String>.from(d['rooms']  ?? []),
              );
            }).toList());
  }
}
