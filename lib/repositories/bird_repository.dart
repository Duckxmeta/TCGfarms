// lib/repositories/bird_repository.dart
//
// Single place that talks to the `animals` Firestore collection.
// Screens should depend on this instead of building their own
// FirebaseFirestore queries, so there's one query to fix/optimize
// and streams can be shared instead of duplicated per-screen.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bird.dart';

class BirdRepository {
  final FirebaseFirestore _db;

  BirdRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  /// Live stream of the current user's flock, mapped to [Bird] models.
  Stream<List<Bird>> watchMyBirds() {
    return _db
        .collection('animals')
        .where('owner_id', isEqualTo: _uid)
        .snapshots()
        .map((snap) => snap.docs.map(Bird.fromFirestore).toList());
  }

  /// Live stream of the entire public registry (used by the Global Registry tab).
  Stream<List<Bird>> watchRegistry() {
    return _db.collection('animals').snapshots().map(
          (snap) => snap.docs.map(Bird.fromFirestore).toList(),
        );
  }

  Future<Bird?> getById(String id) async {
    final doc = await _db.collection('animals').doc(id).get();
    if (!doc.exists) return null;
    return Bird.fromFirestore(doc);
  }

  Future<String> addBird(Bird bird) async {
    final ref = await _db.collection('animals').add(bird.toFirestore());
    return ref.id;
  }

  Future<void> updateBird(String id, Map<String, dynamic> data) {
    return _db.collection('animals').doc(id).update(data);
  }

  Future<void> deleteBird(String id) {
    return _db.collection('animals').doc(id).delete();
  }
}
