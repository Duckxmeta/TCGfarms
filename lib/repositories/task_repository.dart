// lib/repositories/task_repository.dart
//
// Fixes a real bug from the previous version: checking off a daily task
// only updated an in-memory Map, so progress was lost the moment you left
// the screen. Completion state now lives in Firestore, keyed by user + day,
// so it survives navigation, app restarts, and rolls over automatically
// at midnight (a new date = a new, empty completion doc).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskRepository {
  final FirebaseFirestore _db;

  TaskRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  String get _todayKey {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  DocumentReference<Map<String, dynamic>> get _todayDoc =>
      _db.collection('task_completions').doc('${_uid}_$_todayKey');

  /// Live map of taskId -> completed for today.
  Stream<Map<String, bool>> watchTodayCompletions() {
    return _todayDoc.snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return <String, bool>{};
      final raw = data['completed'] as Map<String, dynamic>? ?? {};
      return raw.map((key, value) => MapEntry(key, value == true));
    });
  }

  Future<void> setTaskCompleted(String taskId, bool completed) {
    return _todayDoc.set({
      'uid': _uid,
      'date': _todayKey,
      'completed': {taskId: completed},
    }, SetOptions(merge: true));
  }
}
