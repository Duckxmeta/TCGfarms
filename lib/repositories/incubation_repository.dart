// lib/repositories/incubation_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/incubation_batch.dart';

class IncubationRepository {
  final FirebaseFirestore _db;

  IncubationRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  Stream<List<IncubationBatch>> watchMyBatches() {
    return _db
        .collection('incubation_batches')
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .map((snap) => snap.docs.map(IncubationBatch.fromFirestore).toList());
  }

  Future<String> addBatch(IncubationBatch batch) async {
    final ref = await _db.collection('incubation_batches').add(batch.toFirestore());
    return ref.id;
  }

  Future<void> deleteBatch(String id) {
    return _db.collection('incubation_batches').doc(id).delete();
  }
}
