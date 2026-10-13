import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------- location service ----------------
class LocationService {
  static final _doc =
      FirebaseFirestore.instance.collection('settings').doc('locations');

  // used when nothing is saved in firestore yet
  static const List<String> _defaultLocations = [
    'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7',
    'Sport Complex', 'Chancellor Hall'
  ];

  static Stream<List<String>> stream() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists || snap.data()?['list'] == null)
        return List<String>.from(_defaultLocations);
      return List<String>.from(snap.data()!['list']);
    });
  }

  static Future<List<String>> get() async {
    final snap = await _doc.get();
    if (!snap.exists || snap.data()?['list'] == null)
      return List<String>.from(_defaultLocations);
    return List<String>.from(snap.data()!['list']);
  }

  static Future<void> save(List<String> locations) async {
    await _doc.set({'list': locations});
  }
}
